# receipt-checkpoints

Public, append-only copies of [Permission Protocol](https://permissionprotocol.com)'s
daily receipt checkpoints.

Every day PP signs a checkpoint: the RFC 9162 Merkle root over every receipt chain head
(`leaf_count` chains), signed with a dedicated Ed25519 checkpoint key. PP serves each one at
`https://app.permissionprotocol.com/.well-known/permission-protocol/checkpoints/<YYYY-MM-DD>.json`.
This repository keeps an independent copy, so a later rewrite of a published checkpoint is
detectable: git history here shows when each file first appeared, and the mirror job fails
instead of overwriting a day whose published bytes changed.

- `checkpoints/<YYYY-MM-DD>.json` — the checkpoint exactly as published.
- `keys/<key_id>.json` — every checkpoint public key PP has listed in
  `/.well-known/permission-protocol/keys.json`, recorded the first time it appears, so old
  checkpoints stay verifiable after a key rotation.
- `.github/workflows/mirror.yml` — runs daily (01:47 and 13:47 UTC), fetches the last 7 days,
  never overwrites.

## Verify a checkpoint

`signed_payload` is the exact text signed; `signature_b64` is an Ed25519 signature over it by
the key `key_id`. Check that the payload states the same `period`, `root` and `leaf_count` as the
JSON fields, then verify the signature with the public key in `keys/<key_id>.json`. To check that
a receipt is included, get its inclusion proof from PP and recompute the root for that day.

Design: `docs/trust/design-notes/RECEIPT-CHAIN.md` in the app repository (#882).
