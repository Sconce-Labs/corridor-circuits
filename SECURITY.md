# Security

Open a private security advisory or email the maintainers. Not a public issue.

## Circuit-specific notes

- **A constraint bug = fake passes accepted on Stellar.** The `eligibility.nr`
  failure-mode tests catch regressions; add one for every new constraint.
- **Poseidon2 divergence** across circuit / SDK / Soroban silently breaks every
  Merkle check. `conformance.nr` is the tripwire — keep it green.
- **`auditor_blob` is a hiding commitment, not encryption** — an auditor cannot
  decrypt it yet (corridor-sdk `docs/AUDITOR.md`, M7).
- **Revocation is a sparse Merkle tree** — empty leaf 0, depth 32, slot bound to
  `low_bits(Poseidon2(commitment))`. Collision risk across the 32-bit truncation
  is negligible at testnet scale; an indexed Merkle tree removes it —
  [#2](https://github.com/Sconce-Labs/corridor-circuits/issues/2).
- **Not audited.** Do not use for mainnet value before an external review.
