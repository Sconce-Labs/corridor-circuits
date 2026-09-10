# Changelog

## [Unreleased]

### Added
- `corridor_eligibility` circuit: credential inclusion, revocation
  non-membership, tier, expiry, per-corridor nullifier, bounded tag, auditor
  binding.
- Split into `merkle.nr` / `eligibility.nr` / `test_fixtures.nr` /
  `conformance.nr`; 14 `nargo test` cases including all 8 failure modes.
- Committed `Prover.toml` fixture that `nargo execute` solves in CI.
- Poseidon2 pinned to `corridor-sdk` + `corridor-contracts` by a shared vector.
- `noirup` version pinned to `1.0.0-beta.26`.
