# Contributing

`corridor-circuits` participates in the **Stellar Drips Wave** — see
[Sconce-Labs/corridor `DRIPS.md`](https://github.com/Sconce-Labs/corridor/blob/main/DRIPS.md).
Open issues are labelled `drips`.

## Setup

```bash
# noirup + bbup — https://noir-lang.org/docs/getting_started/quick_start
noirup --version 1.0.0-beta.26
cd corridor_eligibility
nargo check
nargo test          # 14 tests
nargo execute       # solves the committed fixture
nargo fmt --check
```

## Rules

- One issue per PR; `Closes #N`.
- `nargo test`, `nargo execute`, and `nargo fmt --check` must pass.
- **The public-input order** in `main` is an ABI shared with
  `corridor-contracts/ABI.md` and `corridor-sdk`. Changing it is a coordinated
  PR across all three.
- **Poseidon2** must keep matching `conformance::PINNED`.
- Regenerate `Prover.toml` with `corridor-sdk`'s `npm run gen-fixture` after any
  layout change.

## Module map

| File | Role |
|------|------|
| `merkle.nr` | `root_from`, `low_bits`, `hash2` |
| `eligibility.nr` | `Public` / `Witness` structs, `check()`, failure-mode tests |
| `test_fixtures.nr` | `good()` — a deterministic valid witness |
| `conformance.nr` | the pinned Poseidon2 vector |
| `main.nr` | the `pub` I/O adapter over `eligibility::check` |
