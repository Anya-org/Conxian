#!/usr/bin/env python3
"""Reject unsafe consumers of proof-of-reserves state and legacy APIs."""
from pathlib import Path
import re
import sys
from typing import TypeAlias

ROOT = Path(__file__).resolve().parent.parent
POR_CONTRACT = Path("contracts/security/proof-of-reserves.clar")
SAFE_STATUS_FUNCTIONS = {"is-fully-backed", "get-proof-status"}
LEGACY_DEFINITIONS = {"sync-on-chain-balance", "set-oracle-aggregator", "get-reserve-data", "get-attestation", "get-reserve-ratio", "remove-attestor"}
SExpr: TypeAlias = str | list["SExpr"]


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


def tokenize(source: str) -> list[str]:
    """Tokenize enough Clarity syntax for conservative local call analysis."""

    clean = strip_comments_and_strings(source)
    tokens: list[str] = []
    atom: list[str] = []
    for char in clean:
        if char in "()" or char.isspace():
            if atom:
                tokens.append("".join(atom))
                atom = []
            if char in "()":
                tokens.append(char)
        else:
            atom.append(char)
    if atom:
        tokens.append("".join(atom))
    return tokens


def parse_sexpressions(source: str) -> list[SExpr]:
    roots: list[SExpr] = []
    stack: list[list[SExpr]] = []
    for token in tokenize(source):
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
            stack[-1].append(token)
        else:
            roots.append(token)
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


def por_calls(source: str) -> list[str]:
    """Return methods called on PoR literals or local aliases."""

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

    calls: list[str] = []

    def walk(expression: SExpr, environment: dict[str, SExpr]) -> None:
        if not isinstance(expression, list) or not expression:
            return
        head = expression[0].lower() if isinstance(expression[0], str) else ""
        if head == "contract-call?" and len(expression) >= 3:
            target, method = expression[1], expression[2]
            if resolves_to_por(target, environment) and isinstance(method, str):
                calls.append(method.lower())
        if head == "let" and len(expression) >= 3 and isinstance(expression[1], list):
            scoped = dict(environment)
            for binding in expression[1]:
                if isinstance(binding, list) and len(binding) >= 2 and isinstance(binding[0], str):
                    scoped[binding[0].lower()] = binding[1]
            for child in expression[2:]:
                walk(child, scoped)
            return
        for child in expression[1:]:
            walk(child, environment)

    for form in forms:
        walk(form, constants)
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
            for function in por_calls(path.read_text(encoding="utf-8")):
                if function not in SAFE_STATUS_FUNCTIONS:
                    errors.append(f"{path.relative_to(root)} calls unsafe proof-of-reserves function {function}; only trait-based fail-closed status APIs are allowed")
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
