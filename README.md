# corridor-circuits

[![CI](https://github.com/Sconce-Labs/corridor-circuits/actions/workflows/ci.yml/badge.svg)](https://github.com/Sconce-Labs/corridor-circuits/actions/workflows/ci.yml)

`corridor_eligibility` — the Noir circuit a holder runs client-side to prove
they may enter a **Corridor** payment corridor, without revealing who they are.

- Product + architecture: **[Sconce-Labs/corridor](https://github.com/Sconce-Labs/corridor)**
- Soroban contracts + the ABI source of truth: **[Sconce-Labs/corridor-contracts](https://github.com/Sconce-Labs/corridor-contracts)** ([`ABI.md`](https://github.com/Sconce-Labs/corridor-contracts/blob/main/ABI.md))
- Client SDK: **[Sconce-Labs/corridor-sdk](https://github.com/Sconce-Labs/corridor-sdk)**

## What it proves

See the doc comment at the top of
[`corridor_eligibility/src/main.nr`](./corridor_eligibility/src/main.nr).
In one line: *"I hold an unexpired, unrevoked credential of tier ≥ N issued by
an accepted issuer, and here is a per-corridor nullifier that can't be linked
to my other corridors."*

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

Built and tested against **Noir `1.0.0-beta.26`** (`nargo check` + `nargo test`
green in CI). Poseidon2 from `noir-lang/poseidon` `v0.3.0`.

## Known gaps

- Real Merkle fixtures + a witness builder; `Prover.toml` here is shape-only.
- **Poseidon2 conformance** — confirm `noir-lang/poseidon` v0.3.0's permutation
  is byte-identical to Soroban's `poseidon2_permutation` host function and the
  Compact tree hashing. Until that test exists, the cross-chain Merkle roots are
  assumed-equal, not proven-equal. **Correctness gate before the real verifier.**
- `auditor_blob` is a hiding commitment, not real encryption yet — replace with
  in-circuit ECIES so a warranted auditor can decrypt (`{tier, issuer}` for a
  flagged nullifier).
- Revocation is a sparse Merkle tree (empty leaf = 0, depth 32). Revisit vs. an
  indexed Merkle tree if revocation volume grows.

## License

Apache-2.0
