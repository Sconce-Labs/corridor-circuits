# Benchmarks

`nargo info` on `1.0.0-beta.26`, `noir-lang/poseidon` v0.3.0, `DEPTH = 32`.

| Function | ACIR opcodes | Brillig opcodes |
|----------|-------------:|----------------:|
| `main` | ~3200 | 34 |

Dominated by the depth-32 Poseidon2 Merkle folds (credential inclusion + the
indexed-Merkle-tree low-leaf inclusion) and the 254-bit `to_le_bits`
decompositions in `lt_248` (two per proof) and `key_of` (one). The jump from
~1536 came with the C1 fix (real indexed-Merkle-tree non-membership replacing
the no-op sparse check).

Regenerate: `make info` (or `cd corridor_eligibility && nargo info`). CI prints
this on every run.

## Levers if proving cost matters

- Reduce `DEPTH` if a corridor's credential count is small (the tree depth is
  the same on Midnight, so this is a cross-repo change).
- The revocation `to_le_bits(254)` can shrink to `to_le_bits(DEPTH + margin)`
  once we bound the field range — small saving.
- An indexed Merkle tree (`docs/REVOCATION.md`) trades the slot decomposition
  for a range proof; roughly neutral on gates, better on soundness.
