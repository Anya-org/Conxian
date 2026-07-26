#!/usr/bin/env python3
"""Reject unsafe consumers of proof-of-reserves state and legacy APIs."""
from pathlib import Path
from dataclasses import dataclass
import re
import sys
from typing import TypeAlias

ROOT = Path(__file__).resolve().parent.parent
POR_CONTRACT = Path("contracts/security/proof-of-reserves.clar")
SAFE_STATUS_FUNCTIONS = {"is-fully-backed", "get-proof-status"}
LEGACY_DEFINITIONS = {"sync-on-chain-balance", "set-oracle-aggregator", "get-reserve-data", "get-attestation", "get-reserve-ratio", "remove-attestor"}
SExpr: TypeAlias = str | list["SExpr"]


class Atom(str):
    """String-compatible token carrying its source line."""

    line: int

    def __new__(cls, value: str, line: int) -> "Atom":
        instance = super().__new__(cls, value)
        instance.line = line
        return instance


class PorCall(str):
    """Unsafe-or-approved PoR method call with actionable source context."""

    call_name: str
    enclosing_function: str | None
    line: int

    def __new__(
        cls,
        method: str,
        *,
        call_name: str,
        enclosing_function: str | None,
        line: int,
    ) -> "PorCall":
        instance = super().__new__(cls, method)
        instance.call_name = call_name
        instance.enclosing_function = enclosing_function
        instance.line = line
        return instance


@dataclass(frozen=True)
class FunctionDefinition:
    name: str
    parameters: tuple[str, ...]
    bodies: tuple[SExpr, ...]


def strip_comments_and_strings(source: str) -> str:
    output, i, in_string, escaped = [], 0, False, False
    while i < len(source):
        char = source[i]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            output.append(" ")
        elif char == '"':
            in_string = True
            output.append(" ")
        elif source.startswith(";;", i):
            newline = source.find("\n", i)
            if newline < 0:
                output.extend(" " * (len(source) - i))
                break
            output.extend(" " * (newline - i))
            i = newline - 1
        else:
            output.append(char)
        i += 1
    return "".join(output)


def tokenize(source: str) -> list[tuple[str, int]]:
    """Tokenize enough Clarity syntax for conservative local call analysis."""

    clean = strip_comments_and_strings(source)
    tokens: list[tuple[str, int]] = []
    atom: list[str] = []
    atom_line = 1
    line = 1
    for char in clean:
        if char in "()" or char.isspace():
            if atom:
                tokens.append(("".join(atom), atom_line))
                atom = []
            if char in "()":
                tokens.append((char, line))
        else:
            if not atom:
                atom_line = line
            atom.append(char)
        if char == "\n":
            line += 1
    if atom:
        tokens.append(("".join(atom), atom_line))
    return tokens


def parse_sexpressions(source: str) -> list[SExpr]:
    roots: list[SExpr] = []
    stack: list[list[SExpr]] = []
    for token, line in tokenize(source):
        if token == "(":
            form: list[SExpr] = []
            if stack:
                stack[-1].append(form)
            else:
                roots.append(form)
            stack.append(form)
        elif token == ")":
            if stack:
                stack.pop()
        elif stack:
            stack[-1].append(Atom(token, line))
        else:
            roots.append(Atom(token, line))
    return roots


def is_por_principal(atom: str) -> bool:
    normalized = atom.lower().lstrip("'")
    return normalized == ".proof-of-reserves" or normalized.endswith(".proof-of-reserves")


def resolves_to_por(expression: SExpr, environment: dict[str, SExpr], seen: set[str] | None = None) -> bool:
    if isinstance(expression, list):
        return any(resolves_to_por(item, environment, seen) for item in expression)
    if is_por_principal(expression):
        return True
    seen = set() if seen is None else seen
    key = expression.lower()
    if key in seen or key not in environment:
        return False
    seen.add(key)
    return resolves_to_por(environment[key], environment, seen)


def expression_line(expression: SExpr) -> int:
    if isinstance(expression, Atom):
        return expression.line
    if isinstance(expression, list):
        for item in expression:
            line = expression_line(item)
            if line:
                return line
    return 0


def function_definitions(forms: list[SExpr]) -> dict[str, FunctionDefinition]:
    definitions: dict[str, FunctionDefinition] = {}
    for form in forms:
        if not isinstance(form, list) or len(form) < 3 or not isinstance(form[0], str):
            continue
        if form[0].lower() not in {"define-private", "define-public", "define-read-only"}:
            continue
        signature = form[1]
        if not isinstance(signature, list) or not signature or not isinstance(signature[0], str):
            continue
        parameters: list[str] = []
        valid = True
        for declaration in signature[1:]:
            if not isinstance(declaration, list) or not declaration or not isinstance(declaration[0], str):
                valid = False
                break
            parameters.append(declaration[0].lower())
        if valid:
            name = signature[0].lower()
            definitions[name] = FunctionDefinition(name, tuple(parameters), tuple(form[2:]))
    return definitions


def parameter_flow_summaries(
    definitions: dict[str, FunctionDefinition],
) -> dict[str, tuple[frozenset[str], ...]]:
    """Find methods each function parameter can reach as a dynamic call target."""

    summaries: dict[str, tuple[frozenset[str], ...]] = {
        name: tuple(frozenset() for _ in definition.parameters)
        for name, definition in definitions.items()
    }

    def origins(expression: SExpr, environment: dict[str, frozenset[int]]) -> frozenset[int]:
        if isinstance(expression, list):
            combined: set[int] = set()
            for child in expression:
                combined.update(origins(child, environment))
            return frozenset(combined)
        return environment.get(expression.lower(), frozenset())

    def analyze(
        expression: SExpr,
        environment: dict[str, frozenset[int]],
        result: list[set[str]],
    ) -> None:
        if not isinstance(expression, list) or not expression:
            return
        head = expression[0].lower() if isinstance(expression[0], str) else ""
        if head == "contract-call?" and len(expression) >= 3 and isinstance(expression[2], str):
            for parameter_index in origins(expression[1], environment):
                result[parameter_index].add(expression[2].lower())
        elif head in summaries:
            for parameter_index, methods in enumerate(summaries[head]):
                argument_index = parameter_index + 1
                if argument_index >= len(expression):
                    continue
                for origin in origins(expression[argument_index], environment):
                    result[origin].update(methods)
        if head == "let" and len(expression) >= 3 and isinstance(expression[1], list):
            scoped = dict(environment)
            for binding in expression[1]:
                if isinstance(binding, list) and len(binding) >= 2 and isinstance(binding[0], str):
                    analyze(binding[1], scoped, result)
                    scoped[binding[0].lower()] = origins(binding[1], scoped)
            for child in expression[2:]:
                analyze(child, scoped, result)
            return
        if head == "match" and len(expression) in {5, 6}:
            matched = expression[1]
            matched_origins = origins(matched, environment)
            analyze(matched, environment, result)
            if isinstance(expression[2], str):
                success_scope = dict(environment)
                success_scope[expression[2].lower()] = matched_origins
                analyze(expression[3], success_scope, result)
            else:
                analyze(expression[3], environment, result)
            if len(expression) == 5:
                analyze(expression[4], environment, result)
            elif isinstance(expression[4], str):
                error_scope = dict(environment)
                error_scope[expression[4].lower()] = matched_origins
                analyze(expression[5], error_scope, result)
            else:
                analyze(expression[5], environment, result)
            return
        for child in expression[1:]:
            analyze(child, environment, result)

    changed = True
    while changed:
        changed = False
        for name, definition in definitions.items():
            result = [set(methods) for methods in summaries[name]]
            environment = {
                parameter: frozenset({index})
                for index, parameter in enumerate(definition.parameters)
            }
            for body in definition.bodies:
                analyze(body, environment, result)
            updated = tuple(frozenset(methods) for methods in result)
            if updated != summaries[name]:
                summaries[name] = updated
                changed = True
    return summaries


def por_calls(source: str) -> list[PorCall]:
    """Return PoR methods reached directly or through local helper parameters."""

    forms = parse_sexpressions(source)
    constants: dict[str, SExpr] = {}
    for form in forms:
        if (
            isinstance(form, list)
            and len(form) >= 3
            and isinstance(form[0], str)
            and form[0].lower() == "define-constant"
            and isinstance(form[1], str)
        ):
            constants[form[1].lower()] = form[2]

    definitions = function_definitions(forms)
    summaries = parameter_flow_summaries(definitions)
    calls: list[PorCall] = []

    def record(method: str, call_name: str, expression: SExpr, enclosing_function: str | None) -> None:
        calls.append(
            PorCall(
                method.lower(),
                call_name=call_name,
                enclosing_function=enclosing_function,
                line=expression_line(expression),
            )
        )

    def walk(expression: SExpr, environment: dict[str, SExpr], enclosing_function: str | None = None) -> None:
        if not isinstance(expression, list) or not expression:
            return
        head = expression[0].lower() if isinstance(expression[0], str) else ""
        if head == "contract-call?" and len(expression) >= 3:
            target, method = expression[1], expression[2]
            if resolves_to_por(target, environment) and isinstance(method, str):
                record(method, "contract-call?", expression, enclosing_function)
        elif head in summaries:
            for parameter_index, methods in enumerate(summaries[head]):
                argument_index = parameter_index + 1
                if argument_index < len(expression) and resolves_to_por(expression[argument_index], environment):
                    for method in sorted(methods):
                        record(method, head, expression, enclosing_function)
        if head == "let" and len(expression) >= 3 and isinstance(expression[1], list):
            scoped = dict(environment)
            for binding in expression[1]:
                if isinstance(binding, list) and len(binding) >= 2 and isinstance(binding[0], str):
                    walk(binding[1], scoped, enclosing_function)
                    scoped[binding[0].lower()] = binding[1]
            for child in expression[2:]:
                walk(child, scoped, enclosing_function)
            return
        if head == "match" and len(expression) in {5, 6}:
            matched = expression[1]
            walk(matched, environment, enclosing_function)
            if isinstance(expression[2], str):
                success_scope = dict(environment)
                success_scope[expression[2].lower()] = matched
                walk(expression[3], success_scope, enclosing_function)
            else:
                walk(expression[3], environment, enclosing_function)
            if len(expression) == 5:
                walk(expression[4], environment, enclosing_function)
            elif isinstance(expression[4], str):
                error_scope = dict(environment)
                error_scope[expression[4].lower()] = matched
                walk(expression[5], error_scope, enclosing_function)
            else:
                walk(expression[5], environment, enclosing_function)
            return
        for child in expression[1:]:
            walk(child, environment, enclosing_function)

    for form in forms:
        environment = dict(constants)
        enclosing_function = None
        if (
            isinstance(form, list)
            and len(form) >= 3
            and isinstance(form[0], str)
            and form[0].lower() in {"define-private", "define-public", "define-read-only"}
            and isinstance(form[1], list)
            and form[1]
            and isinstance(form[1][0], str)
        ):
            enclosing_function = form[1][0].lower()
            for declaration in form[1][1:]:
                if isinstance(declaration, list) and declaration and isinstance(declaration[0], str):
                    environment.pop(declaration[0].lower(), None)
            for body in form[2:]:
                walk(body, environment, enclosing_function)
            continue
        walk(form, environment, enclosing_function)
    return calls


def collect_errors(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    por_path = root / POR_CONTRACT
    if not por_path.is_file():
        return [f"missing {POR_CONTRACT}"]
    por_source = strip_comments_and_strings(por_path.read_text(encoding="utf-8"))
    for legacy in sorted(LEGACY_DEFINITIONS):
        if re.search(rf"\(\s*define-(?:public|read-only)\s+\(\s*{re.escape(legacy)}\b", por_source):
            errors.append(f"{POR_CONTRACT} retains deprecated callable {legacy}")
    if "oracle-aggregator" in por_source:
        errors.append(f"{POR_CONTRACT} conflates price-oracle configuration with PoR authority")
    for primitive in ("secp256k1-verify", "to-consensus-buff?"):
        if not re.search(rf"\(\s*{re.escape(primitive)}(?:\s|\()", por_source):
            errors.append(f"{POR_CONTRACT} is missing {primitive}")
    contracts = root / "contracts"
    if contracts.is_dir():
        for path in sorted(contracts.rglob("*.clar")):
            if path.resolve() == por_path.resolve():
                continue
            for call in por_calls(path.read_text(encoding="utf-8")):
                if call not in SAFE_STATUS_FUNCTIONS:
                    caller = f" in {call.enclosing_function}" if call.enclosing_function else ""
                    line = f":{call.line}" if call.line else ""
                    errors.append(
                        f"{path.relative_to(root)}{line}{caller} passes proof-of-reserves to "
                        f"{call.call_name}, which can call unsafe function {call}; only trait-based "
                        "fail-closed status APIs are allowed"
                    )
    return errors


def main() -> int:
    errors = collect_errors()
    if errors:
        print("Proof-of-reserves boundary guard failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Proof-of-reserves boundary guard passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
