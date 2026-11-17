#!/usr/bin/env bash
# Copy Permission Protocol's published daily receipt checkpoints into this
# repository, unchanged. A copy outside PP's infrastructure is what makes a later
# rewrite of a published checkpoint detectable (receipt-chain runbook §4, #882).
#
# - Fetches the last $DAYS UTC days (default 7) so a missed run catches up.
# - Never overwrites: if a day already mirrored is now served with different
#   bytes, the run fails loudly (that is the tampering signal) and nothing is
#   changed.
# - Records every checkpoint public key listed in keys.json under keys/, so
#   checkpoints stay verifiable after a key rotation (runbook §7).
set -euo pipefail

BASE="${PP_BASE:-https://app.permissionprotocol.com}/.well-known/permission-protocol"
DAYS="${DAYS:-7}"
cd "$(dirname "$0")/.."
mkdir -p checkpoints keys
mismatch=0

for offset in $(seq 1 "$DAYS"); do
  day=$(date -u -d "-${offset} day" +%F)
  tmp=$(mktemp)
  code=$(curl -sS -o "$tmp" -w '%{http_code}' "$BASE/checkpoints/${day}.json" || echo 000)
  if [ "$code" = 404 ]; then rm -f "$tmp"; continue; fi
  if [ "$code" != 200 ]; then echo "::warning::${day}: HTTP ${code}"; rm -f "$tmp"; continue; fi
  if ! jq -e --arg d "$day" '.period == $d and (.signature_b64|type=="string") and (.signed_payload|type=="string")' "$tmp" >/dev/null; then
    echo "::error::${day}: response is not a checkpoint for that day"; rm -f "$tmp"; mismatch=1; continue
  fi
  dest="checkpoints/${day}.json"
  if [ -f "$dest" ]; then
    if ! cmp -s "$tmp" "$dest"; then
      echo "::error::${day}: the published checkpoint differs from the copy mirrored earlier. Possible rewrite; investigate before changing anything."
      diff <(jq -S . "$dest") <(jq -S . "$tmp") || true
      mismatch=1
    fi
    rm -f "$tmp"
  else
    mv "$tmp" "$dest"; echo "mirrored ${day}"
  fi
done

keys_tmp=$(mktemp)
if curl -sSf -o "$keys_tmp" "$BASE/keys.json"; then
  jq -c '.checkpoint_keys // [] | .[]' "$keys_tmp" | while read -r key; do
    id=$(jq -r '.key_id // .keyId // .kid // empty' <<<"$key")
    [ -n "$id" ] || continue
    dest="keys/${id}.json"
    if [ -f "$dest" ]; then
      # Status may change (active -> retired); the key material must not.
      [ "$(jq -r .public_key_b64 <<<"$key")" = "$(jq -r .public_key_b64 "$dest")" ] || { echo "::error::checkpoint key ${id} now has a different public key than first recorded"; exit 1; }
    else
      jq -S . <<<"$key" > "$dest"; echo "recorded key ${id}"
    fi
  done
fi
rm -f "$keys_tmp"
exit "$mismatch"
