<!-- Closes #NNN -->

## What

## Why

## Checklist
- [ ] `nargo test` + `nargo execute` + `nargo fmt --check` pass
- [ ] New constraint has a `should_fail_with` test in `eligibility.nr`
- [ ] Public-input layout unchanged, or `corridor-contracts/ABI.md` + `corridor-sdk` updated in matching PRs
- [ ] `Prover.toml` regenerated if the layout changed
- [ ] `conformance.nr` still green
