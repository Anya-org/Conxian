#!/usr/bin/env bash
# Register the vault autonomics chainhook with Hiro Platform API.
# Requires: HIRO_PLATFORM_API (e.g. https://api.testnet.hiro.so), HIRO_API_KEY, VAULT_CONTRACT
# Optional: CHAINHOOK_URL (delivery URL), CHAINHOOK_BEARER (delivery bearer token)
set -euo pipefail
: "${HIRO_PLATFORM_API:=https://api.testnet.hiro.so}" || true
: "${VAULT_CONTRACT:?VAULT_CONTRACT env required}" || true
: "${HIRO_API_KEY:?HIRO_API_KEY env required}" || true

# Optional delivery overrides
: "${CHAINHOOK_URL:=}" || true
: "${CHAINHOOK_BEARER:=}" || true

HOOK_FILE="chainhooks/vault_autonomics_chainhook.json"
TMP=$(mktemp)

# Substitute contract, optional URL and bearer.
# Use '|' as the sed delimiter to avoid escaping slashes in URLs and tokens.
SED_SCRIPT="s|{VAULT_CONTRACT}|${VAULT_CONTRACT}|g"
if [[ -n "$CHAINHOOK_URL" ]]; then
  # Replace the example delivery URL with the provided CHAINHOOK_URL.
  SED_SCRIPT+=$'\n'"s|https://example.com/autonomics-hook|${CHAINHOOK_URL}|g"
fi
if [[ -n "$CHAINHOOK_BEARER" ]]; then
  # Replace the example bearer token with the provided CHAINHOOK_BEARER.
  SED_SCRIPT+=$'\n'"s|Bearer CHANGE_ME|Bearer ${CHAINHOOK_BEARER}|g"
fi

sed -e "$SED_SCRIPT" "$HOOK_FILE" > "$TMP"

echo "[+] Registering chainhook from $HOOK_FILE for $VAULT_CONTRACT"
HTTP_RES=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $HIRO_API_KEY" \
  -H 'Content-Type: application/json' \
  "$HIRO_PLATFORM_API/chainhooks" \
  --data-binary @"$TMP")
BODY="$(echo "$HTTP_RES" | head -n1)"
CODE="$(echo "$HTTP_RES" | tail -n1)"
if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
  echo "[!] Failed ($CODE): $BODY" >&2
  exit 1
fi
echo "[+] Registered: $BODY"
rm -f "$TMP"
