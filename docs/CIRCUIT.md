# `corridor_eligibility` — constraint walkthrough

Public inputs (order = the ABI in `corridor-contracts/ABI.md`):

| # | name | type | meaning |
|--:|------|------|---------|
| 0 | `credential_root` | Field | Midnight issued-credential Merkle root (synced to Stellar) |
| 1 | `revocation_root` | Field | Midnight revocation Merkle root |
| 2 | `corridor_id` | Field | which corridor this proof is for |
| 3 | `min_tier` | u32 | corridor's minimum KYC tier |
| 4 | `now` | u64 | current time (checked on Stellar against a tolerance) |
| 5 | `nullifier` | Field | one-time-per-corridor tag |
| 6 | `disclosed_tag` | u32 | bounded enum the holder chose to reveal |
| 7 | `issuer_id` | Field | which issuer (public by design) |
| 8 | `auditor_pubkey` | Field | auditor key the blob binds to (`== policy.auditor_pubkey`; `0` = none) |
| 9 | `auditor_blob` | Field | warrant-scoped binding of `{tier, issuer, nullifier}` |

Private witness: `holder_secret, tier, expiry, salt, cred_siblings[32],
cred_index_bits[32], rev_low_{value,next_index,next_value},
rev_low_siblings[32], rev_low_index_bits[32], auditor_nonce`.

## The constraints (`eligibility::check`)

1. **Commitment.** `c = Poseidon2(holder_secret, tier, expiry, issuer_id, salt)`
   — reconstructed, never an input.
2. **Inclusion.** `root_from(c, cred_siblings, cred_index_bits) == credential_root`.
   Proves the issuer put `c` in the issued set without revealing which leaf.
3. **Non-revocation (indexed Merkle tree).** `key = imtKey(Poseidon2(c))`. Supply
   the low leaf `L` with `L.value < key`; prove `L` is in the tree and
   `key < L.next_value` (or `L` is the tail). A revoked `key` is itself a leaf,
   so no valid `L` exists → fail. See `docs/REVOCATION.md`.
4. **Tier.** `tier >= min_tier`.
5. **Expiry.** `expiry > now`.
6. **Nullifier.** `Poseidon2(holder_secret, corridor_id) == nullifier`. Per
   corridor → two corridors get unlinkable nullifiers for the same holder.
7. **Tag bound.** `disclosed_tag < 16` — an enum index, not free text.
8. **Auditor binding.**
   `Poseidon2(auditor_pubkey, tier, issuer_id, nullifier, auditor_nonce) == auditor_blob`,
   with `auditor_pubkey` a public input the Stellar contract pins to the policy.
   MVP is a hiding commitment; M7 replaces it with real ECIES.

`issuer_id ∈ accepted_issuers` is **not** checked here — the corridor's policy on
Stellar checks it against a short allowlist, so the circuit stays fixed-size.

## What an observer learns

On-chain: a pass was granted on `corridor_id`, tagged `disclosed_tag`, burning
`nullifier`, from `issuer_id`. Not: the holder, their tier, expiry, salt, or
their activity on other corridors.
