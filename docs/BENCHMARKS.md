# Benchmarks

`nargo info` on `1.0.0-beta.26`, `noir-lang/poseidon` v0.3.0,
`noir-lang/schnorr` v0.4.0.

| Function | ACIR opcodes | Brillig opcodes |
|----------|-------------:|----------------:|
| `main` | 73 | (see CI) |

Dominated by the Grumpkin Schnorr `verify_signature` (one embedded-curve scalar
mul + a Poseidon2 challenge) plus a handful of Poseidon2 hashes (holder
binding, statement, issuer id, nullifier, auditor blob).

The earlier Merkle-inclusion design (credential path + indexed-Merkle-tree
low-leaf non-membership, `DEPTH = 32`) was **~3200 ACIR opcodes**. Option B —
issuer-signed statements, no Merkle path — cut that by ~40×.

Regenerate: `cd corridor_eligibility && nargo info`. CI prints this on every
run.

## Levers if proving cost matters

At 73 opcodes there is little to squeeze. If it ever matters:

- The 128-bit limb splitting of `s` / `e` is fixed by the `noir-lang/schnorr`
  ABI — not tunable here.
- Batching multiple corridor entries into one proof (shared signature check,
  N nullifiers) would amortise the scalar mul.
