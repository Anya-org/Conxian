#!/usr/bin/env python3
"""Fail closed if the quarantined ZKML verifier regresses.

This is deliberately a quarantine tripwire, not a general Clarity analyzer.
The only accepted contract shape is the current fail-closed scaffold:

* ``verify-proof`` keeps its exact public ABI and directly returns
  ``ERR_VERIFIER_UNAVAILABLE`` (``err u503``);
* ``get-protocol-status`` directly returns the same unavailable error;
* the scaffold has no helper, event, status, or success boundary; and
* the contract remains available only to Clarinet/simnet negative tests and is
  absent from checked-in testnet/mainnet release plans.

The parser intentionally understands only the balanced S-expression surface
needed for this narrow assertion. Comments, quoted strings/escapes, nested
parentheses/braces, whitespace, and delimiter mismatches are handled so a
substring mutation cannot move a positive path outside a brittle text window.
Any parse or invariant error fails closed.

Future qualification of a real verifier must deliberately revise this guard
and its adversarial tests; it must not silently broaden this scaffold.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
import re
import sys
from typing import Any, Iterable

try:
    import yaml
except ModuleNotFoundError as exc:  # pragma: no cover - exercised by the CLI
    raise SystemExit(
        "PyYAML==6.0.2 is required for the ZKML quarantine guard; "
        "run it with: uv run --with 'PyYAML==6.0.2' python3 "
        "scripts/verify_zkml_quarantine.py"
    ) from exc


ROOT = Path(__file__).resolve().parent.parent

CONTRACT_RELATIVE_PATH = Path("contracts/compliance/zkml-verifier.clar")
CLARINET_RELATIVE_PATH = Path("Clarinet.toml")
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

# These are the active/historical ZKML boundary documents corrected by the
# quarantine change. Archive/roadmap prose is not treated as current release
# evidence by this tripwire and is intentionally outside this narrow list.
ACTIVE_DOC_RELATIVE_PATHS = (
    Path("PRD.md"),
    Path("contracts/compliance/README.md"),
    Path("docs/CONXIAN_SYSTEM_RESEARCH_SYNOPSIS.md"),
    Path("docs/DOCUMENTATION_STATE.md"),
    Path("docs/ORACLE_PRODUCTION_CONFIGURATION.md"),
    Path("docs/SYSTEM_ALIGNMENT_AUDIT_MARCH_2026.md"),
    Path("docs/ZKML_EVIDENCE_CONTRACT.md"),
)
HISTORICAL_DOC_RELATIVE_PATH = Path("docs/STANDARDS_VALIDATION_SESSION_25.md")

# Accept the contract name in YAML keys, IDs, aliases, and source paths. The
# separator is deliberately optional so a compact alias such as
# ``zkmlVerifier`` cannot bypass the release-plan tripwire.
CONTRACT_IDENTIFIER_RE = re.compile(
    r"(?<![a-z0-9])zkml[-_./\s]*verifier(?![a-z0-9])",
    re.IGNORECASE,
)
ZKML_DOC_ANCHOR_RE = re.compile(
    r"\b(?:zkml|zero\s+knowledge\s+machine\s+learning|verifier)\b",
    re.IGNORECASE,
)
DOC_DISCLAIMER_RE = re.compile(
    r"\b(?:quarantin\w*|scaffold\w*|unavailable|disabled|"
    r"non[- ]production|not\s+production|fail[- ]closed|not\s+claimed|"
    r"excluded\s+from)\b",
    re.IGNORECASE,
)
DOC_POSITIVE_PATTERNS = (
    ("active", re.compile(r"\bactive\b", re.IGNORECASE)),
    ("compliant", re.compile(r"\bcompliant\b", re.IGNORECASE)),
    (
        "implemented",
        re.compile(r"\b(?:implemented|implements)\b", re.IGNORECASE),
    ),
    ("verified", re.compile(r"\bverified\b", re.IGNORECASE)),
    ("operational", re.compile(r"\boperational\b", re.IGNORECASE)),
    ("qualified", re.compile(r"\bqualified\b", re.IGNORECASE)),
    ("enabled", re.compile(r"\benabled\b", re.IGNORECASE)),
    ("integrated", re.compile(r"\bintegrated\b", re.IGNORECASE)),
    (
        "production-ready",
        re.compile(r"\bproduction\s+ready\b", re.IGNORECASE),
    ),
)
DIRECT_NEGATION_RE = re.compile(
    r"\b(?:not|never|no|without|non|neither|unavailable|disabled|"
    r"absent|pending|cannot|can't)\b(?:\s+\w+){0,8}\s*$",
    re.IGNORECASE,
)
POST_NEGATION_RE = re.compile(
    r"^\s*(?:(?:is|are|was|were|remains?|seems?)\s+)?"
    r"(?:not|never|unavailable|disabled|pending)\b",
    re.IGNORECASE,
)
DOC_CLAUSE_BOUNDARY_RE = re.compile(
    r"(?P<punct>[,;:\u2013\u2014])|"
    r"(?P<conjunction>\b(?:but|however|yet|although|while|whereas|and|or)\b)",
    re.IGNORECASE,
)
DOC_CONTRASTIVE_CONJUNCTIONS = frozenset(
    {"but", "however", "yet", "although", "while", "whereas", "and", "or"}
)
DOC_CONTINUATION_PREFIX_WORDS = frozenset(
    {
        "a",
        "an",
        "are",
        "be",
        "been",
        "being",
        "cannot",
        "can't",
        "had",
        "has",
        "have",
        "is",
        "it",
        "must",
        "never",
        "no",
        "not",
        "now",
        "remain",
        "remains",
        "seem",
        "seems",
        "should",
        "still",
        "that",
        "the",
        "this",
        "was",
        "were",
    }
)
STATUS_MARKER_RE = re.compile(r"(?:active|compliant|verified)", re.IGNORECASE)
EVENT_HEADS = frozenset({"print", "emit", "emit-event", "emit-event?"})


@dataclass(frozen=True)
class Atom:
    value: str
    quoted: bool = False


@dataclass(frozen=True)
class Form:
    opener: str
    items: tuple["Expression", ...]


Expression = Atom | Form
Token = str | Atom


class ParseError(ValueError):
    """Raised when a source file is not a balanced Clarity expression stream."""


def _tokenize(source: str) -> list[Token]:
    """Tokenize enough Clarity syntax to safely parse nested forms."""

    tokens: list[Token] = []
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
                if character == "\\":
                    if index + 1 >= len(source):
                        raise ParseError("unterminated string escape")
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
    """Parse a balanced stream of parenthesized/braced Clarity forms."""

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

        expected_closer = closing_for[token]
        items: list[Expression] = []
        while True:
            if position >= len(tokens):
                raise ParseError(f"unclosed form beginning with {token}")
            next_token = tokens[position]
            if next_token == expected_closer:
                position += 1
                return Form(token, tuple(items))
            if next_token in closing_tokens:
                raise ParseError(
                    f"mismatched closing delimiter {next_token} for {token}"
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


def _is_atom(
    expression: Expression,
    value: str,
    *,
    quoted: bool | None = None,
) -> bool:
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
    forms: Iterable[Expression],
    kind: str,
    name: str,
) -> list[Form]:
    return [
        form
        for form in forms
        if isinstance(form, Form)
        and _definition_header(form) == (kind, name)
    ]


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
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        errors.append(f"could not read {_relative_label(path, root)}: {exc}")
        return ""
    if not text.strip():
        errors.append(f"empty required file: {_relative_label(path, root)}")
        return ""
    return text


def _error_literal(expression: Expression, code: str) -> bool:
    return (
        isinstance(expression, Form)
        and expression.opener == "("
        and len(expression.items) == 2
        and _is_atom(expression.items[0], "err", quoted=False)
        and _is_atom(expression.items[1], code, quoted=False)
    )


def _signature_matches(
    signature: Expression,
    name: str,
    parameters: tuple[tuple[str, tuple[str, ...]], ...],
) -> bool:
    if not isinstance(signature, Form) or signature.opener != "(":
        return False
    if len(signature.items) != len(parameters) + 1 or not _is_atom(
        signature.items[0], name, quoted=False
    ):
        return False

    for parameter, (parameter_name, type_parts) in zip(
        signature.items[1:], parameters
    ):
        if (
            not isinstance(parameter, Form)
            or parameter.opener != "("
            or len(parameter.items) != 2
            or not _is_atom(parameter.items[0], parameter_name, quoted=False)
        ):
            return False

        parameter_type = parameter.items[1]
        if len(type_parts) == 1:
            if not _is_atom(parameter_type, type_parts[0], quoted=False):
                return False
            continue

        if (
            not isinstance(parameter_type, Form)
            or parameter_type.opener != "("
            or len(parameter_type.items) != len(type_parts)
            or any(
                not _is_atom(item, expected, quoted=False)
                for item, expected in zip(parameter_type.items, type_parts)
            )
        ):
            return False
    return True


def _canonical_unavailable_body(body: tuple[Expression, ...]) -> bool:
    """Accept only direct ERR or a one-expression ``begin`` wrapper."""

    if len(body) != 1:
        return False
    expression = body[0]
    if _is_atom(expression, "ERR_VERIFIER_UNAVAILABLE", quoted=False):
        return True
    return (
        isinstance(expression, Form)
        and expression.opener == "("
        and len(expression.items) == 2
        and _is_atom(expression.items[0], "begin", quoted=False)
        and _is_atom(
            expression.items[1], "ERR_VERIFIER_UNAVAILABLE", quoted=False
        )
    )


def _verify_contract(errors: list[str], root: Path) -> None:
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

    definitions: list[tuple[Form, tuple[str, str]]] = []
    for form in forms:
        header = _definition_header(form)
        if header is None:
            errors.append(
                f"{_relative_label(contract_path, root)} contains an unexpected "
                "top-level expression; quarantine definitions must remain explicit"
            )
            continue
        definitions.append((form, header))

    allowed_definitions = {
        ("define-constant", "ERR_VERIFIER_UNAVAILABLE"),
        ("define-constant", "ERR_UNAUTHORIZED"),
        ("define-data-var", "admin"),
        ("define-public", "verify-proof"),
        ("define-public", "set-admin"),
        ("define-read-only", "get-protocol-status"),
    }
    for _, header in definitions:
        if header not in allowed_definitions:
            errors.append(
                "zkml-verifier contains an unexpected definition/callable "
                f"{header[0]} {header[1]}; future qualification must revise "
                "the allowlist deliberately"
            )

    unavailable_constants = _definitions(
        forms, "define-constant", "ERR_VERIFIER_UNAVAILABLE"
    )
    if len(unavailable_constants) != 1:
        errors.append("ERR_VERIFIER_UNAVAILABLE must be defined exactly once")
    elif len(unavailable_constants[0].items) != 3 or not _error_literal(
        unavailable_constants[0].items[2], "u503"
    ):
        errors.append("ERR_VERIFIER_UNAVAILABLE must map exactly to (err u503)")

    unauthorized_constants = _definitions(forms, "define-constant", "ERR_UNAUTHORIZED")
    if len(unauthorized_constants) != 1:
        errors.append("ERR_UNAUTHORIZED must be defined exactly once for set-admin")
    elif len(unauthorized_constants[0].items) != 3 or not _error_literal(
        unauthorized_constants[0].items[2], "u7002"
    ):
        errors.append("ERR_UNAUTHORIZED must map exactly to (err u7002)")

    admin_vars = _definitions(forms, "define-data-var", "admin")
    if len(admin_vars) != 1:
        errors.append("admin must be defined exactly once for set-admin")
    elif (
        len(admin_vars[0].items) != 4
        or not _is_atom(admin_vars[0].items[2], "principal", quoted=False)
        or not _is_atom(admin_vars[0].items[3], "tx-sender", quoted=False)
    ):
        errors.append("admin must remain a principal initialized from tx-sender")

    public_verify = _definitions(forms, "define-public", "verify-proof")
    if len(public_verify) != 1:
        errors.append("verify-proof must be defined exactly once as public")
    else:
        function = public_verify[0]
        expected_parameters = (
            ("model-id", ("string-ascii", "64")),
            ("input-hash", ("buff", "32")),
            ("proof", ("buff", "1024")),
        )
        if len(function.items) < 2 or not _signature_matches(
            function.items[1], "verify-proof", expected_parameters
        ):
            errors.append(
                "verify-proof ABI must be exactly model-id (string-ascii 64), "
                "input-hash (buff 32), proof (buff 1024)"
            )
        if not _canonical_unavailable_body(function.items[2:]):
            errors.append(
                "verify-proof body must be exactly ERR_VERIFIER_UNAVAILABLE "
                "(or a one-expression begin wrapper); branches, length checks, "
                "helper calls, and success paths are forbidden"
            )

    public_admin = _definitions(forms, "define-public", "set-admin")
    if len(public_admin) != 1:
        errors.append("set-admin must be defined exactly once as public")
    else:
        function = public_admin[0]
        if len(function.items) < 3 or not _signature_matches(
            function.items[1], "set-admin", (("new-admin", ("principal",)),)
        ):
            errors.append("set-admin ABI must remain (new-admin principal)")
        # Do not classify set-admin's legitimate (ok true) administration
        # response as a verifier success. Only verify-proof/status bodies are
        # subject to the direct-unavailable-body assertion above.

    read_only_status = _definitions(forms, "define-read-only", "get-protocol-status")
    if len(read_only_status) != 1:
        errors.append("get-protocol-status must be defined exactly once as read-only")
    else:
        function = read_only_status[0]
        if len(function.items) < 2 or not _signature_matches(
            function.items[1], "get-protocol-status", ()
        ):
            errors.append("get-protocol-status ABI must have no parameters")
        if not _canonical_unavailable_body(function.items[2:]):
            errors.append(
                "get-protocol-status body must resolve only to "
                "ERR_VERIFIER_UNAVAILABLE"
            )

    event_reported = False
    marker_reported = False
    for form in forms:
        for expression in _walk(form):
            if isinstance(expression, Atom):
                value = expression.value.casefold()
                if not expression.quoted and value in EVENT_HEADS and not event_reported:
                    errors.append(
                        "quarantined zkml-verifier must not contain print/event expressions"
                    )
                    event_reported = True
                if STATUS_MARKER_RE.search(expression.value) and not marker_reported:
                    errors.append(
                        "quarantined zkml-verifier must not contain active/compliant/verified "
                        "status markers"
                    )
                    marker_reported = True


def _yaml_string_occurrences(
    value: Any,
    *,
    location: str = "$",
    seen: set[int] | None = None,
) -> Iterable[tuple[str, str]]:
    """Yield decoded YAML strings, including keys, list items, and aliases."""

    if isinstance(value, str):
        if CONTRACT_IDENTIFIER_RE.search(value):
            yield location, value
        return

    if seen is None:
        seen = set()
    if isinstance(value, (Mapping, Sequence)) and not isinstance(
        value, (str, bytes, bytearray)
    ):
        value_id = id(value)
        if value_id in seen:
            return
        seen.add(value_id)

    if isinstance(value, Mapping):
        for key, item in value.items():
            yield from _yaml_string_occurrences(
                key, location=f"{location}.<key>", seen=seen
            )
            yield from _yaml_string_occurrences(
                item, location=f"{location}[{key!r}]", seen=seen
            )
    elif isinstance(value, Sequence) and not isinstance(
        value, (str, bytes, bytearray)
    ):
        for index, item in enumerate(value):
            yield from _yaml_string_occurrences(
                item, location=f"{location}[{index}]", seen=seen
            )


def _verify_release_plan(
    errors: list[str], relative_path: Path, source: str
) -> None:
    """Parse and inspect one release plan using only PyYAML's safe loader."""

    try:
        document = yaml.safe_load(source)
    except Exception as exc:  # PyYAML parse, decode, and constructor failures
        errors.append(
            f"{relative_path} is not valid YAML for quarantine scanning: {exc}"
        )
        return

    for location, value in _yaml_string_occurrences(document):
        errors.append(
            f"{relative_path} contains the quarantined zkml-verifier in decoded "
            f"YAML string at {location} ({value!r}); release plans must exclude "
            "the contract under every YAML key/form"
        )


def _verify_release_classification(errors: list[str], root: Path) -> None:
    clarinet = read_text(root / CLARINET_RELATIVE_PATH, errors, root)
    if clarinet and not CONTRACT_IDENTIFIER_RE.search(clarinet):
        errors.append(
            "Clarinet.toml must retain zkml-verifier for local compilation/negative tests"
        )

    simnet = read_text(root / SIMNET_PLAN_RELATIVE_PATH, errors, root)
    if simnet and not CONTRACT_IDENTIFIER_RE.search(simnet):
        errors.append(
            "default.simnet-plan.yaml must retain zkml-verifier for local negative tests"
        )

    for relative_path in RELEASE_CLASSIFICATION_RELATIVE_PATHS:
        source = read_text(root / relative_path, errors, root)
        if source and not CONTRACT_IDENTIFIER_RE.search(source):
            errors.append(
                f"{relative_path} must explicitly classify zkml-verifier as quarantined"
            )

    for relative_path in RELEASE_PLAN_RELATIVE_PATHS:
        plan = read_text(root / relative_path, errors, root)
        if plan:
            _verify_release_plan(errors, relative_path, plan)


def _normalize_document(text: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", text.casefold()))


def _document_sentences(text: str) -> Iterable[str]:
    """Yield sentence-sized units without treating wrapped lines as claims."""

    start = 0
    for boundary in re.finditer(r"[.!?]+(?=\s|$)", text):
        sentence = text[start : boundary.start()]
        if sentence.strip():
            yield sentence
        start = boundary.end()
    remainder = text[start:]
    if remainder.strip():
        yield remainder


def _document_clauses(sentence: str) -> Iterable[tuple[str, bool]]:
    """Yield clause text and whether a contrastive continuation precedes it."""

    start = 0
    continuation = False
    for boundary in DOC_CLAUSE_BOUNDARY_RE.finditer(sentence):
        segment = sentence[start : boundary.start()]
        if segment.strip():
            yield segment, continuation
            continuation = False

        conjunction = boundary.group("conjunction")
        if conjunction and conjunction.casefold() in DOC_CONTRASTIVE_CONJUNCTIONS:
            continuation = True
        start = boundary.end()

    remainder = sentence[start:]
    if remainder.strip():
        yield remainder, continuation


def _is_negated_positive(normalized: str, start: int, end: int) -> bool:
    """Apply negation only inside the current sentence clause."""

    prefix = normalized[:start]
    suffix = normalized[end:]
    if DIRECT_NEGATION_RE.search(prefix):
        return True
    return POST_NEGATION_RE.search(suffix) is not None


def _looks_like_continuation(
    normalized: str, positive_start: int | None = None
) -> bool:
    """Recognize an elliptical continuation without importing a new subject."""

    if positive_start is None:
        positive_start = len(normalized)
    prefix_words = normalized[:positive_start].split()
    return len(prefix_words) <= 5 and all(
        word in DOC_CONTINUATION_PREFIX_WORDS for word in prefix_words
    )


def _positive_document_claims(text: str) -> list[str]:
    claims: list[str] = []

    # Keep each positive term in its own punctuation/conjunction clause. A
    # negation attached to ``compliant`` must not suppress a later ``verified``
    # claim in ``not compliant, but verified``. Contrastive clauses inherit the
    # prior ZKML subject only when their wording is an elliptical continuation.
    previous_sentence_anchor = False
    for sentence in _document_sentences(text.casefold()):
        previous_clause_anchor = False
        sentence_anchor = False
        for clause, continuation in _document_clauses(sentence):
            normalized = _normalize_document(clause)
            if not normalized:
                continue
            anchors = tuple(ZKML_DOC_ANCHOR_RE.finditer(normalized))
            sentence_anchor = sentence_anchor or bool(anchors)

            clause_anchor = bool(anchors)
            for label, pattern in DOC_POSITIVE_PATTERNS:
                for match in pattern.finditer(normalized):
                    direct_anchor = any(
                        0 <= match.start() - anchor.end() <= 180
                        for anchor in anchors
                    )
                    inherited_anchor = (
                        (continuation and previous_clause_anchor)
                        or (
                            continuation
                            and not previous_clause_anchor
                            and previous_sentence_anchor
                        )
                    ) and _looks_like_continuation(normalized, match.start())
                    if not direct_anchor and not inherited_anchor:
                        continue
                    if _is_negated_positive(
                        normalized, match.start(), match.end()
                    ):
                        continue
                    start = max(0, match.start() - 70)
                    end = min(len(normalized), match.end() + 70)
                    claims.append(f"{label}: {normalized[start:end]}")
                    clause_anchor = True

            previous_clause_anchor = clause_anchor or (
                continuation and previous_clause_anchor
            )
        previous_sentence_anchor = sentence_anchor or previous_clause_anchor
    return claims


def _verify_documentation(errors: list[str], root: Path) -> None:
    for relative_path in ACTIVE_DOC_RELATIVE_PATHS:
        path = root / relative_path
        text = read_text(path, errors, root)
        if not text:
            continue
        if not CONTRACT_IDENTIFIER_RE.search(text) and not re.search(
            r"\b(?:zkml|zero[- ]knowledge)\b", text, re.IGNORECASE
        ):
            errors.append(
                f"{relative_path} does not document the ZKML quarantine boundary"
            )
        if not DOC_DISCLAIMER_RE.search(text):
            errors.append(
                f"{relative_path} lacks an explicit unavailable/scaffold/non-production disclaimer"
            )
        for claim in _positive_document_claims(text):
            errors.append(
                f"{relative_path} contains an unnegated positive ZKML claim: {claim}"
            )

    historical_path = root / HISTORICAL_DOC_RELATIVE_PATH
    historical = read_text(historical_path, errors, root)
    if historical:
        if not re.search(r"\bhistorical\b", historical, re.IGNORECASE):
            errors.append(
                "STANDARDS_VALIDATION_SESSION_25.md must be explicitly marked historical"
            )
        if not re.search(r"\bsuperseded\b", historical, re.IGNORECASE):
            errors.append(
                "STANDARDS_VALIDATION_SESSION_25.md must be explicitly marked superseded"
            )
        if not DOC_DISCLAIMER_RE.search(historical):
            errors.append(
                "STANDARDS_VALIDATION_SESSION_25.md lacks an explicit ZKML disclaimer"
            )
        for claim in _positive_document_claims(historical):
            errors.append(
                "STANDARDS_VALIDATION_SESSION_25.md contains an unnegated positive "
                f"ZKML claim: {claim}"
            )


def collect_errors(root: Path = ROOT) -> list[str]:
    """Collect all guard failures using an injected repository root."""

    root = Path(root).resolve()
    errors: list[str] = []
    _verify_contract(errors, root)
    _verify_release_classification(errors, root)
    _verify_documentation(errors, root)
    return errors


def main(root: Path = ROOT) -> int:
    errors = collect_errors(root)
    if errors:
        print("FAIL: ZKML quarantine guard detected regression(s):", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        "PASS: ZKML quarantine guard confirms the fail-closed scaffold, local-only "
        "classification, release exclusion, and documentation boundary."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
