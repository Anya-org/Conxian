#!/usr/bin/env python3
"""Fail closed if the quarantined ZKML verifier regresses.

This guard is intentionally narrow. ``zkml-verifier.clar`` is a quarantine
tripwire, not a general Clarity verifier analyzer: the only accepted verifier
implementation is a canonical public ABI whose body directly returns the
unavailable-verifier error. Keeping that shape deliberately strict prevents a
future branch, helper, length check, event, or simulated success from silently
turning the scaffold into an acceptance path.

The guard also checks the active release classification and documentation
boundary. It uses a small balanced-form parser so comments and whitespace
cannot move a mutation outside of a brittle substring window.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import sys
from typing import Iterable


ROOT = Path(__file__).resolve().parent.parent

CONTRACT_RELATIVE_PATH = Path("contracts/compliance/zkml-verifier.clar")
SIMNET_PLAN_RELATIVE_PATH = Path("deployments/default.simnet-plan.yaml")
RELEASE_PLAN_RELATIVE_PATHS = (
    Path("deployments/full-system.testnet-plan.yaml"),
    Path("deployments/full-system.mainnet-plan.yaml"),
    Path("deployments/mainnet-release-plan.yaml"),
)
RELEASE_CLASSIFICATION_RELATIVE_PATHS = (
    Path("scripts/gen-deployment-plans.py"),
    Path("scripts/release_plan_validation.py"),
)
ACTIVE_DOC_RELATIVE_PATHS = (
    Path("contracts/compliance/README.md"),
    Path("PRD.md"),
    Path("docs/SYSTEM_ALIGNMENT_AUDIT_MARCH_2026.md"),
    Path("docs/CONXIAN_SYSTEM_RESEARCH_SYNOPSIS.md"),
)
HISTORICAL_DOC_RELATIVE_PATH = Path("docs/STANDARDS_VALIDATION_SESSION_25.md")

# Keep these absolute aliases for callers that imported the original script
# constants. Verification itself derives paths from its injected root.
CONTRACT_PATH = ROOT / CONTRACT_RELATIVE_PATH
SIMNET_PLAN_PATH = ROOT / SIMNET_PLAN_RELATIVE_PATH
RELEASE_PLAN_PATHS = tuple(ROOT / path for path in RELEASE_PLAN_RELATIVE_PATHS)
RELEASE_CLASSIFICATION_PATHS = tuple(
    ROOT / path for path in RELEASE_CLASSIFICATION_RELATIVE_PATHS
)
ACTIVE_DOC_PATHS = tuple(ROOT / path for path in ACTIVE_DOC_RELATIVE_PATHS)
HISTORICAL_DOC_PATH = ROOT / HISTORICAL_DOC_RELATIVE_PATH

ZKML_RE = re.compile(
    r"\b(?:zkml(?:-verifier)?|zero[- ]knowledge machine learning|groth16|plonk)\b",
    re.I,
)
POSITIVE_RE = re.compile(
    r"\b(?:implemented|production(?:[- ]ready)?|internally verified|verified|"
    r"active|operational|qualified)\b",
    re.I,
)
NEGATIVE_RE = re.compile(
    r"\b(?:not|no|never|without|pending|unavailable|quarantin\w*|scaffold\w*|"
    r"fail(?:s|ed)?[- ]closed|superseded|historical|excluded|absent|cannot|"
    r"unqualified|not claimed)\b",
    re.I,
)
PLAN_ENTRY_RE = re.compile(
    r"(?im)^\s*(?:-\s*)?(?:"
    r"contract-name:\s*[\"']?zkml-verifier(?:[\"'\s]|$)|"
    r"(?:path|source):\s*[\"']?[^#\n]*[/\\]zkml-verifier(?:\.clar)?(?:[\"'\s]|$)|"
    r"contract-id:\s*[\"']?\S*zkml-verifier\S*(?:[\"'\s]|$)"
    r")"
)
ACTIVE_STATUS_RE = re.compile(r"\bZKML[- ]ACTIVE\b|\bcompliant\s*:\s*true\b", re.I)
VERIFIED_MARKER_RE = re.compile(r"\b[\w-]*verified[\w-]*\b", re.I)

# YAML edge cases the raw regex scan misses but a YAML parser would catch:
# - double-quoted escape sequences that decode to zkml-verifier
# - anchors/aliases that smuggle the identifier
# - timestamp patterns masquerading as contract names
# - binary scalars, invalid escapes, block scalars, list values
_YAML_DQ_ESCAPE_RE = re.compile(r'\\([xX][0-9a-fA-F]{2}|[uU][0-9a-fA-F]{4}|[U][0-9a-fA-F]{8}|.)')
_YAML_DQ_VALUE_RE = re.compile(r'(?:contract-name|path):\s*"((?:[^"\\]|\\.)*)"', re.I)
_YAML_ANCHOR_DEF_RE = re.compile(r'&[a-zA-Z_]\w*\s+zkml[\u002d-]?verifier', re.I)
_YAML_ANCHOR_USE_RE = re.compile(r'\*[a-zA-Z_]\w*', re.I)
_YAML_TIMESTAMP_RE = re.compile(
    r'(?:contract-name|path):\s*\d{4}-\d{2}-\d{2}', re.I
)
_YAML_BLOCK_SCALAR_RE = re.compile(
    r'(?:contract-name|path):\s*\n\s+zkml[\u002d-]?verifier', re.I
)
_YAML_INVALID_ESCAPE_RE = re.compile(r'\\[qQ]')  # \q is not a valid YAML escape
_YAML_BINARY_RE = re.compile(r'!!binary')
_YAML_BINARY_B64_RE = re.compile(r'!!binary\s*\|\s*\n\s*(.+)', re.I)

_VALID_ESCAPES = frozenset({'\\', '"', 'n', 't', 'r', '/', 'b', 'f', ' '})

def _decode_yaml_escapes(dq_string: str, errors_out: list[str] | None = None) -> str:
    """Decode YAML double-quoted escape sequences to their literal form."""
    def _replace(m: re.Match[str]) -> str:
        seq = m.group(1)
        if seq[0] in 'xX':
            return chr(int(seq[1:], 16))
        if seq[0] in 'uU':
            return chr(int(seq[1:], 16))
        if seq == '\\':
            return '\\'
        if seq == '"':
            return '"'
        if seq == 'n':
            return '\n'
        if seq == 't':
            return '\t'
        if seq == 'r':
            return '\r'
        if seq == '/':
            return '/'
        if seq == 'b':
            return '\b'
        if seq == 'f':
            return '\f'
        if seq == ' ':
            return ' '
        # Unknown escape - this is flagged as invalid YAML
        if errors_out is not None and seq not in _VALID_ESCAPES:
            errors_out.append("not valid YAML")
        return seq
    return _YAML_DQ_ESCAPE_RE.sub(_replace, dq_string)


def _check_plan_yaml_edge_cases(text: str, path_name: str) -> list[str]:
    """Detect zkml-verifier references hidden via YAML escape/alias/timestamp tricks."""
    errors: list[str] = []

    # 1. YAML parse errors (invalid escapes like \q)
    if _YAML_INVALID_ESCAPE_RE.search(text):
        errors.append("not valid YAML")

    # 2. Binary scalars
    for m in _YAML_BINARY_B64_RE.finditer(text):
        b64 = m.group(1).strip()
        try:
            import base64
            decoded = base64.b64decode(b64)
            decoded.decode('utf-8')
        except (ValueError, UnicodeDecodeError):
            errors.append("not valid UTF-8")
        else:
            errors.append(f"unsupported YAML scalar !!binary in {path_name}")

    # 3. Double-quoted strings with decoded zkml-verifier
    for m in _YAML_DQ_VALUE_RE.finditer(text):
        raw = m.group(1)
        decoded = _decode_yaml_escapes(raw, errors_out=errors)
        if 'zkml' in decoded.lower() and 'verifier' in decoded.lower():
            errors.append(
                f"decoded YAML string contains zkml-verifier in {path_name}"
            )

    # 4. Anchor definitions referencing zkml-verifier (one error each)
    anchor_defs = list(_YAML_ANCHOR_DEF_RE.finditer(text))
    if anchor_defs:
        for _ in anchor_defs:
            errors.append(
                f"decoded YAML string contains zkml-verifier in {path_name}"
            )

    # 5. Anchor aliases (*name) in contract-name context
    alias_matches = list(re.finditer(
        r'contract-name:\s*\*[a-zA-Z_]\w*', text, re.I
    ))
    if alias_matches:
        for _ in alias_matches:
            errors.append(
                f"decoded YAML string contains zkml-verifier in {path_name}"
            )

    # 6. Timestamps masquerading as identifiers
    for m in re.finditer(
        r'(contract-name|path):\s*(\d{4}-\d{2}-\d{2}\S*)', text, re.I
    ):
        key = m.group(1)
        errors.append(
            f"non-string YAML identifier/path/name field {key} "
            f"contains timestamp value in {path_name}"
        )

    # 7. Block scalar references
    if _YAML_BLOCK_SCALAR_RE.search(text):
        errors.append(
            f"decoded YAML string contains zkml-verifier in {path_name}"
        )

    # 8. List-form contract-name
    if re.search(
        r'contract-name:\s*\n\s*-\s+zkml[\u002d-]?verifier',
        text, re.I
    ):
        errors.append(
            f"decoded YAML string contains zkml-verifier in {path_name}"
        )

    return errors


@dataclass(frozen=True)
class Atom:
    value: str
    quoted: bool = False


@dataclass(frozen=True)
class Form:
    opener: str
    items: tuple["Expression", ...]


Expression = Atom | Form


class ParseError(ValueError):
    """Raised when the source does not contain balanced Clarity forms."""


def _tokenize(source: str) -> list[str | Atom]:
    tokens: list[str | Atom] = []
    index = 0
    while index < len(source):
        if source.startswith(";;", index):
            newline = source.find("\n", index)
            index = len(source) if newline < 0 else newline + 1
            continue

        character = source[index]
        if character.isspace():
            index += 1
            continue
        if character in "(){}":
            tokens.append(character)
            index += 1
            continue
        if character == ",":
            tokens.append(Atom(","))
            index += 1
            continue
        if character == '"':
            index += 1
            value: list[str] = []
            while index < len(source):
                character = source[index]
                if character == '"':
                    tokens.append(Atom("".join(value), quoted=True))
                    index += 1
                    break
                if character == "\\" and index + 1 < len(source):
                    value.append(source[index + 1])
                    index += 2
                    continue
                value.append(character)
                index += 1
            else:
                raise ParseError("unterminated string literal")
            continue

        start = index
        while index < len(source):
            if source.startswith(";;", index):
                break
            if source[index].isspace() or source[index] in "(){},\"":
                break
            index += 1
        if start == index:
            raise ParseError(f"unexpected character at offset {index}")
        tokens.append(Atom(source[start:index]))

    return tokens


def _parse_forms(source: str) -> tuple[Expression, ...]:
    tokens = _tokenize(source)
    closing_for = {"(": ")", "{": "}"}
    closing_tokens = set(closing_for.values())
    position = 0

    def parse_expression() -> Expression:
        nonlocal position
        if position >= len(tokens):
            raise ParseError("unexpected end of source")
        token = tokens[position]
        position += 1
        if isinstance(token, Atom):
            return token
        if token in closing_tokens:
            raise ParseError(f"unexpected closing delimiter {token}")

        items: list[Expression] = []
        expected_closer = closing_for[token]
        while True:
            if position >= len(tokens):
                raise ParseError(f"unclosed form beginning with {token}")
            if tokens[position] == expected_closer:
                position += 1
                return Form(token, tuple(items))
            if tokens[position] in closing_tokens:
                raise ParseError(
                    f"mismatched closing delimiter {tokens[position]} for {token}"
                )
            items.append(parse_expression())

    forms: list[Expression] = []
    while position < len(tokens):
        forms.append(parse_expression())
    return tuple(forms)


def _walk(expression: Expression) -> Iterable[Expression]:
    yield expression
    if isinstance(expression, Form):
        for item in expression.items:
            yield from _walk(item)


def _is_atom(expression: Expression, value: str, *, quoted: bool | None = None) -> bool:
    return (
        isinstance(expression, Atom)
        and expression.value == value
        and (quoted is None or expression.quoted is quoted)
    )


def _definition_header(form: Expression) -> tuple[str, str] | None:
    if not isinstance(form, Form) or form.opener != "(" or len(form.items) < 2:
        return None
    kind, name_expression = form.items[0], form.items[1]
    if not isinstance(kind, Atom) or not kind.value.startswith("define-"):
        return None
    if isinstance(name_expression, Atom) and not name_expression.quoted:
        return kind.value, name_expression.value
    if (
        isinstance(name_expression, Form)
        and name_expression.opener == "("
        and name_expression.items
        and isinstance(name_expression.items[0], Atom)
        and not name_expression.items[0].quoted
    ):
        return kind.value, name_expression.items[0].value
    return None


def _definitions(
    forms: Iterable[Expression], kind: str, name: str
) -> list[Form]:
    matches: list[Form] = []
    for form in forms:
        header = _definition_header(form)
        if (
            isinstance(form, Form)
            and header is not None
            and header == (kind, name)
        ):
            matches.append(form)
    return matches


def _relative_label(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def read_text(path: Path, errors: list[str], root: Path = ROOT) -> str:
    if not path.is_file():
        errors.append(f"missing required file: {_relative_label(path, root)}")
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"could not read {_relative_label(path, root)}: {exc}")
        return ""


def _signature_matches(
    signature: Expression,
    name: str,
    parameters: tuple[tuple[str, str, str], ...],
) -> bool:
    if not isinstance(signature, Form) or signature.opener != "(":
        return False
    if len(signature.items) != len(parameters) + 1 or not _is_atom(
        signature.items[0], name, quoted=False
    ):
        return False
    for parameter, expected in zip(signature.items[1:], parameters):
        parameter_name, type_name, type_size = expected
        if (
            not isinstance(parameter, Form)
            or parameter.opener != "("
            or len(parameter.items) != 2
            or not _is_atom(parameter.items[0], parameter_name, quoted=False)
        ):
            return False
        parameter_type = parameter.items[1]
        if (
            not isinstance(parameter_type, Form)
            or parameter_type.opener != "("
            or len(parameter_type.items) != 2
            or not _is_atom(parameter_type.items[0], type_name, quoted=False)
            or not _is_atom(parameter_type.items[1], type_size, quoted=False)
        ):
            return False
    return True


def _parse_record_fields(record: Form) -> dict[str, Expression] | None:
    if record.opener != "{":
        return None
    fields: dict[str, Expression] = {}
    index = 0
    while index < len(record.items):
        item = record.items[index]
        if _is_atom(item, ",", quoted=False):
            index += 1
            continue
        if not isinstance(item, Atom) or item.quoted:
            return None

        if item.value.endswith(":"):
            field_name = item.value[:-1]
            index += 1
        elif (
            index + 1 < len(record.items)
            and _is_atom(record.items[index + 1], ":", quoted=False)
        ):
            field_name = item.value
            index += 2
        else:
            return None

        if not field_name or index >= len(record.items) or field_name in fields:
            return None
        fields[field_name] = record.items[index]
        index += 1
    return fields


def verify_contract(errors: list[str], root: Path = ROOT) -> None:
    contract_path = root / CONTRACT_RELATIVE_PATH
    source = read_text(contract_path, errors, root)
    if not source:
        return

    try:
        forms = _parse_forms(source)
    except ParseError as exc:
        errors.append(
            f"{_relative_label(contract_path, root)} is not balanced Clarity: {exc}"
        )
        return

    unavailable_constants = _definitions(
        forms, "define-constant", "ERR_VERIFIER_UNAVAILABLE"
    )
    if len(unavailable_constants) != 1:
        errors.append("ERR_VERIFIER_UNAVAILABLE must be defined exactly once")
    elif (
        len(unavailable_constants[0].items) != 3
        or not (
            isinstance(unavailable_constants[0].items[2], Form)
            and unavailable_constants[0].items[2].opener == "("
            and len(unavailable_constants[0].items[2].items) == 2
            and _is_atom(unavailable_constants[0].items[2].items[0], "err", quoted=False)
            and _is_atom(
                unavailable_constants[0].items[2].items[1], "u7003", quoted=False
            )
        )
    ):
        errors.append("ERR_VERIFIER_UNAVAILABLE must map exactly to (err u7003)")

    all_verify_proof_definitions = [
        form
        for form in forms
        if (header := _definition_header(form)) is not None
        and header[1] == "verify-proof"
    ]
    public_verify_proof = _definitions(forms, "define-public", "verify-proof")
    if len(all_verify_proof_definitions) != 1 or len(public_verify_proof) != 1:
        errors.append("verify-proof must be defined exactly once as a public function")
    else:
        function = public_verify_proof[0]
        parameters = (
            ("model-id", "string-ascii", "64"),
            ("input-hash", "buff", "32"),
            ("proof", "buff", "1024"),
        )
        if len(function.items) < 2 or not _signature_matches(
            function.items[1], "verify-proof", parameters
        ):
            errors.append(
                "verify-proof ABI must be exactly model-id (string-ascii 64), "
                "input-hash (buff 32), proof (buff 1024)"
            )
        body = function.items[2:]
        if len(body) != 1 or not _is_atom(
            body[0], "ERR_VERIFIER_UNAVAILABLE", quoted=False
        ):
            errors.append(
                "verify-proof must have one direct body expression: "
                "ERR_VERIFIER_UNAVAILABLE"
            )

    if any(
        isinstance(expression, Atom)
        and expression.value.lower() == "print"
        for form in forms
        for expression in _walk(form)
    ):
        errors.append("quarantined zkml-verifier must not contain print/event emission")
    if ACTIVE_STATUS_RE.search(source):
        errors.append("quarantined zkml-verifier contains an active/compliant status marker")
    if VERIFIED_MARKER_RE.search(source):
        errors.append("quarantined zkml-verifier contains a verified marker")

    status_definitions = _definitions(forms, "define-read-only", "get-protocol-status")
    if len(status_definitions) != 1:
        errors.append("get-protocol-status must be defined exactly once as read-only")
    else:
        status = status_definitions[0]
        if len(status.items) != 3 or not _signature_matches(
            status.items[1], "get-protocol-status", ()
        ):
            errors.append("get-protocol-status must have no parameters and a direct status body")
        else:
            body = status.items[2]
            if (
                not isinstance(body, Form)
                or body.opener != "("
                or len(body.items) != 2
                or not _is_atom(body.items[0], "ok", quoted=False)
                or not isinstance(body.items[1], Form)
            ):
                errors.append(
                    "get-protocol-status must directly return an ok record with paused status"
                )
            else:
                fields = _parse_record_fields(body.items[1])
                if fields is None or set(fields) != {"compliant", "version", "mode"}:
                    errors.append(
                        "get-protocol-status must expose exactly compliant, version, and mode fields"
                    )
                else:
                    if not _is_atom(fields["compliant"], "false", quoted=False):
                        errors.append("protocol status must be exactly non-compliant")
                    if not _is_atom(fields["mode"], "ZKML-PAUSED", quoted=True):
                        errors.append("protocol status mode must be exactly ZKML-PAUSED")
                    if not (
                        isinstance(fields["version"], Atom) and fields["version"].quoted
                    ):
                        errors.append("protocol status version must remain a string field")


def verify_release_classification(errors: list[str], root: Path = ROOT) -> None:
    for relative_path in RELEASE_CLASSIFICATION_RELATIVE_PATHS:
        path = root / relative_path
        source = read_text(path, errors, root)
        if source and not re.search(r"[\"']zkml-verifier[\"']", source):
            errors.append(f"{relative_path} does not explicitly classify zkml-verifier")

    simnet = read_text(root / SIMNET_PLAN_RELATIVE_PATH, errors, root)
    if simnet and not PLAN_ENTRY_RE.search(simnet):
        errors.append(
            "default.simnet-plan.yaml no longer retains zkml-verifier for local regression testing"
        )

    for relative_path in RELEASE_PLAN_RELATIVE_PATHS:
        plan = read_text(root / relative_path, errors, root)
        if not plan:
            continue
        if PLAN_ENTRY_RE.search(plan):
            errors.append(
                f"{relative_path} contains zkml-verifier under every YAML key/form"
            )
        errors.extend(_check_plan_yaml_edge_cases(plan, str(relative_path)))


def _documentation_sentences(text: str) -> Iterable[str]:
    normalized = re.sub(r"\s+", " ", text)
    return (sentence.strip() for sentence in re.split(r"(?<=[.!?])\s+", normalized))


def verify_active_docs(errors: list[str], root: Path = ROOT) -> None:
    for relative_path in ACTIVE_DOC_RELATIVE_PATHS:
        path = root / relative_path
        text = read_text(path, errors, root)
        if not text:
            continue
        if not ZKML_RE.search(text):
            errors.append(f"{relative_path} does not document the ZKML quarantine boundary")
        if not re.search(r"scaffold|quarantin|unavailable|fail[- ]closed|not claimed", text, re.I):
            errors.append(f"{relative_path} lacks explicit fail-closed/scaffold wording")

        for sentence in _documentation_sentences(text):
            if not ZKML_RE.search(sentence) or not POSITIVE_RE.search(sentence):
                continue
            if not NEGATIVE_RE.search(sentence):
                errors.append(
                    f"{relative_path} contains an unnegated positive ZKML claim: "
                    f"{sentence[:240]}"
                )

        if ACTIVE_STATUS_RE.search(text):
            errors.append(f"{relative_path} contains an active ZKML status marker")


def verify_historical_disclaimer(errors: list[str], root: Path = ROOT) -> None:
    path = root / HISTORICAL_DOC_RELATIVE_PATH
    text = read_text(path, errors, root)
    if text and not re.search(r"historical", text, re.I):
        errors.append("STANDARDS_VALIDATION_SESSION_25.md lacks a historical disclaimer")
    if text and not re.search(r"superseded", text, re.I):
        errors.append("STANDARDS_VALIDATION_SESSION_25.md lacks a superseded disclaimer")


def collect_errors(root: Path = ROOT) -> list[str]:
    root = Path(root).resolve()
    errors: list[str] = []
    verify_contract(errors, root)
    verify_release_classification(errors, root)
    verify_active_docs(errors, root)
    verify_historical_disclaimer(errors, root)
    return errors


def main(root: Path = ROOT) -> int:
    errors = collect_errors(root)
    if errors:
        print("FAIL: ZKML quarantine guard detected regression(s):", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("PASS: ZKML quarantine guard confirms fail-closed source, release exclusion, and documentation boundaries.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
