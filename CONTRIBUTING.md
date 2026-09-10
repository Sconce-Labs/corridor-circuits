# Contributing

`corridor-circuits` participates in the **Stellar Drips Wave** — see
[Sconce-Labs/corridor `DRIPS.md`](https://github.com/Sconce-Labs/corridor/blob/main/DRIPS.md).
Open issues are labelled `drips`.

## Setup

```bash
# noirup — https://noir-lang.org/docs/getting_started/quick_start
noirup --version 1.0.0-beta.26
cd corridor_eligibility
nargo check
nargo test          # 18 tests
nargo execute       # solves the committed fixture
nargo fmt --check
```

## Rules

- One issue per PR; `Closes #N`.
- `nargo test`, `nargo execute`, and `nargo fmt --check` must pass.
- **The public-input order** in `main` is an ABI shared with
  `corridor-contracts/ABI.md` and `corridor-sdk`. Changing it is a coordinated
  PR across all three.
- **Poseidon2** must keep matching `conformance::PINNED`; the **Schnorr** scheme
  must keep matching `corridor-sdk/src/schnorr.ts` (pinned to `noir-lang/schnorr`).
- Regenerate the fixture with `corridor-sdk`'s `npm run gen-fixture -- --write`
  after any layout or scheme change.

## Module map

| File | Role |
|------|------|
| `eligibility.nr` | `Public` / `Witness` structs, `check()`, failure-mode tests |
| `eligibility/fixture.nr` | `good()` — a valid witness with a real SDK signature |
| `tags.nr` | `DisclosureTag` constants |
| `conformance.nr` | the pinned Poseidon2 vector |
| `main.nr` | the `pub` I/O adapter over `eligibility::check` |
