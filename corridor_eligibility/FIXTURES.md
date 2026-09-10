# The committed `Prover.toml`

`Prover.toml` is a **valid** witness — `nargo execute` solves every constraint
against it, in CI, on every push. It is generated, not hand-written.

## Regenerate

From `corridor-sdk` (which owns the tree-building + Poseidon2 logic):

```bash
cd ../corridor-sdk
npm run gen-fixture > ../corridor-circuits/corridor_eligibility/Prover.toml
```

Do this after **any** change to:

- the public-input order in `main`
- the commitment / nullifier / auditor-blob formulas in `eligibility.nr`
- `DEPTH` or the empty-leaf convention in `merkle.nr`

## In-circuit fixture

`test_fixtures::good()` builds the same shape directly in Noir for the
`nargo test` cases — keep the two in sync (holder at leaf 0, empty trees).
