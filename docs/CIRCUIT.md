# `corridor_eligibility` — constraint walkthrough

Design: **Option B** (issuer-signed statements, no Merkle accumulator) —
[corridor/docs/CREDENTIAL_ACCUMULATOR.md](https://github.com/Sconce-Labs/corridor/blob/main/docs/CREDENTIAL_ACCUMULATOR.md).

Public inputs (order = the ABI in `corridor-contracts/ABI.md`), 9:

| # | name | type | meaning |
|--:|------|------|---------|
| 0 | `corridor_id` | Field | which corridor this proof is for |
| 1 | `min_tier` | u32 | corridor's minimum KYC tier |
| 2 | `now` | u64 | current time (checked on Stellar against a tolerance) |
| 3 | `nullifier` | Field | one-time-per-corridor tag |
| 4 | `disclosed_tag` | u32 | corridor category label (`< 16`), holder-chosen — **not attested** |
| 5 | `issuer_id` | Field | `Poseidon2(issuer_pk.x, issuer_pk.y)` (issuer is public by design) |
| 6 | `min_cred_epoch` | u64 | corridor's bulk-revocation floor |
| 7 | `auditor_pubkey` | Field | auditor key the blob binds to (`== policy.auditor_pubkey`; `0` = none) |
| 8 | `auditor_blob` | Field | warrant-scoped binding of `{tier, issuer, nullifier}` |

Private witness: `holder_secret, tier, expiry, cred_epoch, salt, issuer_pk_x,
issuer_pk_y, sig_s_lo, sig_s_hi, sig_e_lo, sig_e_hi, auditor_nonce`.

## The constraints (`eligibility::check`)

1. **Holder binding.** `hb = Poseidon2([holder_secret, salt])` — the issuer
   signed this, never `holder_secret` itself.
2. **Statement.** `m = Poseidon2([hb, tier, expiry, cred_epoch])` — reconstructed.
3. **Issuer signature.** `schnorr::verify_signature(pk, (s, e), m)` — Grumpkin
   Schnorr, Poseidon2 challenge, `noir-lang/schnorr` v0.4.0. Proves an accepted
   issuer attested `{tier, expiry, cred_epoch}` for this holder.
4. **Issuer identity.** `Poseidon2([issuer_pk_x, issuer_pk_y]) == issuer_id`.
5. **Tier.** `tier >= min_tier`.
6. **Expiry.** `expiry > now`.
7. **Epoch floor.** `cred_epoch >= min_cred_epoch` — bulk revocation.
8. **Nullifier.** `Poseidon2([holder_secret, corridor_id]) == nullifier`. Per
   corridor → two corridors get unlinkable nullifiers for the same holder.
9. **Tag range.** `disclosed_tag < MAX_TAG` (16). This is the *only* constraint
   on the tag — it is **not bound** to the credential, the holder, or the tier.
   Treat `PassRecord.tag` as an app-chosen category label, never a verified
   attribute (audit R2-H1).
10. **Auditor binding.**
    `Poseidon2([auditor_pubkey, tier, issuer_id, nullifier, auditor_nonce]) == auditor_blob`,
    with `auditor_pubkey` a public input the Stellar contract pins to the
    policy. MVP is a hiding commitment; M7 replaces it with real ECIES.

`issuer_id ∈ accepted_issuers` is **not** checked here — the corridor's policy
on Stellar checks it against a short allowlist, so the circuit stays fixed-size.

Cost: **73 ACIR opcodes** (the earlier Merkle-inclusion design was ~3200).

## What an observer learns

On-chain: a pass was granted on `corridor_id`, tagged `disclosed_tag`, burning
`nullifier`, from `issuer_id`. Not: the holder, their tier, expiry, cred_epoch,
salt, or their activity on other corridors.
