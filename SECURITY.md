# Security Policy

## Supported versions

Only the latest `main` branch of this repository is supported with security
fixes.

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Use GitHub's private vulnerability reporting: **Security → Report a
vulnerability** on this repository (or open a private advisory). Include a
description, reproduction steps, and your assessment of impact if possible.

We will acknowledge reports within 7 days and aim to ship a fix within 90
days. We credit reporters in the release notes unless you prefer anonymity.

## Circuit-specific notes

- **A constraint bug = fake passes accepted on Stellar.** The `eligibility.nr`
  failure-mode tests catch regressions; add one for every new constraint.
- **Poseidon2 divergence** across circuit / SDK / Soroban, or **Schnorr
  divergence** between this circuit's verifier and the SDK signer, silently
  breaks verification. `conformance.nr`, the SDK's pinned vector, and
  `nargo execute` on the signed fixture are the tripwires.
- **The Grumpkin generator** is pinned (`GY` = the even root, Barretenberg's
  choice). A wrong generator makes every signature fail to verify.
- **`auditor_blob` is a hiding commitment, not encryption** — an auditor
  cannot decrypt it yet (corridor-sdk `docs/AUDITOR.md`, M7).
- **Issuer key compromise** — the circuit trusts any signature by an
  `accepted_issuers` key. Mitigation is off-circuit: short `expiry`,
  `min_cred_epoch` bumps, dropping the issuer from the policy allowlist.
- **`holder_secret` entropy** — it hides the holder and makes nullifiers
  unlinkable. Low entropy = grindable. Issuer/holder tooling must use a
  CSPRNG.
- **Not audited.** Do not use for mainnet value before an external review.
