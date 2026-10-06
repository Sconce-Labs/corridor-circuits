# Contributing to corridor-circuits

Thanks for helping build Corridor — a portable proof-of-eligibility for
cross-border payments (Stellar/Soroban + Noir/UltraHonk). Newcomers welcome:
look for issues labeled `good first issue`. The project overview lives in the
[hub repo](https://github.com/Sconce-Labs/corridor).

## Ground rules

- **One issue per PR.** Reference it with `Closes #NNN`.
- Conventional commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`).
- Don't weaken a trust assumption without updating `ARCHITECTURE.md §6` in the
  hub repo.
- Apache-2.0; by contributing you agree your work is licensed under it.
- We follow the [Code of Conduct](./CODE_OF_CONDUCT.md).

## Setup

```bash
# noirup — https://noir-lang.org/docs/getting_started/quick_start
noirup --version 1.0.0-beta.9
cd corridor_eligibility
nargo check
nargo test          # 20 tests
nargo execute       # solves the committed fixture
nargo fmt --check
```

## What you can work on

- The Noir eligibility circuit (`corridor_eligibility/`): tests, docs,
  constraint clarity, failure-path coverage.
- CI and tooling. **The toolchain pin is load-bearing**: CI pairs Noir
  1.0.0-beta.9 with Barretenberg 0.87.0 to match the on-chain verifier; a bb
  mismatch is not caught by length checks — proofs just stop verifying.
  Coordinate any pin change with corridor-contracts first.
- Dependencies are pinned deliberately: `poseidon` v0.2.6 and a vendored
  `schnorr` v0.4.0 (`vendor/schnorr`, beta.9-compatible; the scheme is pinned
  by the SDK signer). Document any change in the vendored header +
  `conformance.nr`.

## Gates (all must pass)

```bash
nargo fmt --check
nargo check
nargo test
nargo execute
```

## Invariants

- **The public-input order** in `main.nr` is an ABI shared with
  `corridor-contracts/ABI.md` (`PI_*`) and `corridor-sdk`. Changing it is a
  coordinated PR across all three.
- **Poseidon2** must keep matching `conformance::PINNED*`; the **Schnorr**
  scheme must keep matching `corridor-sdk/src/schnorr.ts`.
- Regenerate the fixture with corridor-sdk's
  `npm run gen-fixture -- --write` after any layout or scheme change.

## Module map

| File | Role |
|------|------|
| `eligibility.nr` | `Public` / `Witness` structs, `check()`, failure-mode tests |
| `eligibility/fixture.nr` | `good()` — a valid witness with a real SDK signature |
| `tags.nr` | disclosure tag constants |
| `conformance.nr` | the pinned Poseidon2 vectors (arities 1/2/4/5) |
| `main.nr` | the `pub` I/O adapter over `eligibility::check` |

## Review & merging

Maintainers aim to review within 48h during active contribution waves. Small
PRs get reviewed first — keep diffs reviewable. CI must be green before merge;
if CI fails for reasons outside your control, say so in the PR and we will
pick it up.
