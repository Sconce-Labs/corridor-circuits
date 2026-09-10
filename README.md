# corridor-circuits

[![CI](https://github.com/Sconce-Labs/corridor-circuits/actions/workflows/ci.yml/badge.svg)](https://github.com/Sconce-Labs/corridor-circuits/actions/workflows/ci.yml)

`corridor_eligibility` — the Noir circuit a holder runs client-side to prove
they may enter a **Corridor** payment corridor, without revealing who they are.

- Product + architecture: **[Sconce-Labs/corridor](https://github.com/Sconce-Labs/corridor)**
- Soroban contracts + the ABI source of truth: **[Sconce-Labs/corridor-contracts](https://github.com/Sconce-Labs/corridor-contracts)** ([`ABI.md`](https://github.com/Sconce-Labs/corridor-contracts/blob/main/ABI.md))
- Client SDK: **[Sconce-Labs/corridor-sdk](https://github.com/Sconce-Labs/corridor-sdk)**

## What it proves

In one line: *"I hold an unexpired, unrevoked credential of tier ≥ N issued by
an accepted issuer, and here is a per-corridor nullifier that can't be linked
to my other corridors."*

Full constraint list — credential Merkle inclusion, revocation
non-membership (commitment-bound sparse-tree slot), tier threshold, expiry,
per-corridor nullifier `Poseidon2(secret, corridorId)`, bounded disclosure tag,
auditor-blob binding — is in the doc comment at the top of
[`corridor_eligibility/src/main.nr`](./corridor_eligibility/src/main.nr).

## Public-input ABI

The order of `pub` parameters in `main` is a contract with
`corridor-contracts` (`crates/corridor_types`, the `PI_*` constants):

| idx | name | type |
|----:|------|------|
| 0 | `credential_root` | Field |
| 1 | `revocation_root` | Field |
| 2 | `corridor_id` | Field |
| 3 | `min_tier` | u32 |
| 4 | `now` | u64 |
| 5 | `nullifier` | Field |
| 6 | `disclosed_tag` | u32 |
| 7 | `issuer_id` | Field |
| 8 | `auditor_blob` | Field |

**Change one side → change both, in matching PRs, and update
`corridor-contracts/ABI.md`.**

## Build & prove

```bash
# toolchain: noirup + bbup  (https://noir-lang.org/docs/getting_started/quick_start)
cd corridor_eligibility
nargo check          # type-check
nargo test           # runs the in-circuit #[test] fns
nargo execute        # witness from Prover.toml
bb prove   -b ./target/corridor_eligibility.json -w ./target/corridor_eligibility.gz -o ./target
bb write_vk -b ./target/corridor_eligibility.json -o ./target
# For Soroban, feed the VK + proof to the ultrahonk verifier contract
# (corridor-contracts, milestone M3).
```

Built and tested against **Noir `1.0.0-beta.26`** (`nargo check` + `nargo test`,
3 tests, green in CI). Poseidon2 from `noir-lang/poseidon` `v0.3.0`.

## Poseidon2 conformance

`poseidon2([1, 2]) == 0x038682aa1cb5ae4e0a3f13da432a95c77c5c111f6f030faf9cad641ce1ed7383`
is asserted here (`poseidon2_hash_1_2_matches_the_pinned_vector`), in
`corridor-sdk` (`@zkpassport/poseidon2`), and in
`corridor-contracts/crates/poseidon_conformance` (`stellar/rs-soroban-poseidon`).
Circuit ⇄ SDK ⇄ Soroban agree. The **Midnight** side (`corridor.compact` tree
hashing) still needs the same check — M4.

## Known gaps

- Real Merkle fixtures; `Prover.toml` here is shape-only. The SDK's
  `buildWitness` already assembles a valid witness — wire it to a fixture
  generator.
- `auditor_blob` is a hiding commitment, not real encryption yet — replace with
  in-circuit ECIES so a warranted auditor can decrypt (`{tier, issuer}` for a
  flagged nullifier).
- Revocation is a sparse Merkle tree (empty leaf = 0, depth 32). Revisit vs. an
  indexed Merkle tree if revocation volume grows.

## License

Apache-2.0
