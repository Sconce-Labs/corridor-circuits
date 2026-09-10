# corridor-circuits

[![CI](https://github.com/Sconce-Labs/corridor-circuits/actions/workflows/ci.yml/badge.svg)](https://github.com/Sconce-Labs/corridor-circuits/actions/workflows/ci.yml)
[![Noir](https://img.shields.io/badge/Noir-1.0.0--beta.26-black)](https://noir-lang.org)
[![gates](https://img.shields.io/badge/ACIR-73%20opcodes-brightgreen)](./docs/BENCHMARKS.md)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](./LICENSE)

The **zero-knowledge circuit** at the heart of
[Corridor](https://github.com/Sconce-Labs/corridor) — a portable, private proof
of eligibility for cross-border payments.

`corridor_eligibility` is a **Noir** circuit the holder runs **on their own
device**. It proves:

> *"I hold an unexpired credential of tier ≥ N, signed by the issuer identified
> by `issuer_id`, whose credential epoch is at or above this corridor's
> revocation floor — and here is a per-corridor nullifier that can't be linked
> to my activity anywhere else."*

…while revealing **none** of the holder's identity, tier, expiry, or the
signature itself.

| | |
|---|---|
| **Product & architecture** | [Sconce-Labs/corridor](https://github.com/Sconce-Labs/corridor) |
| **Soroban contracts & the ABI** | [Sconce-Labs/corridor-contracts](https://github.com/Sconce-Labs/corridor-contracts) · [`ABI.md`](https://github.com/Sconce-Labs/corridor-contracts/blob/main/ABI.md) |
| **Client SDK & the signer** | [Sconce-Labs/corridor-sdk](https://github.com/Sconce-Labs/corridor-sdk) |
| **Constraint walkthrough** | [`docs/CIRCUIT.md`](./docs/CIRCUIT.md) |
| **Gate count & benchmarks** | [`docs/BENCHMARKS.md`](./docs/BENCHMARKS.md) |
| **Revocation model** | [`docs/REVOCATION.md`](./docs/REVOCATION.md) |

---

## Design — issuer-signed statements (Option B)

There is **no credential Merkle tree** and no cross-chain accumulator. A
regulated issuer runs KYC once, then signs a short-lived statement with a
**Grumpkin** key (Barretenberg's embedded curve for BN254 — so signature
verification is *native* in Noir, no non-native field arithmetic):

```
holder_binding = Poseidon2([holder_secret, salt])           // issuer never sees holder_secret
statement      = Poseidon2([holder_binding, tier, expiry, cred_epoch])
(s, e)         = schnorr_sign(issuer_sk, statement)          // noir-lang/schnorr v0.4.0
```

The circuit verifies that signature plus every per-corridor predicate. The
earlier "Midnight builds a tree, a relayer syncs the root, the circuit proves
inclusion" design **could not work** — Midnight is BLS12-381, the circuit and
Stellar are BN254, so the roots are values in different fields. See
[`docs/CREDENTIAL_ACCUMULATOR.md`](https://github.com/Sconce-Labs/corridor/blob/main/docs/CREDENTIAL_ACCUMULATOR.md).

---

## Inputs & constraints

**Public inputs (9)** — order is the ABI shared with `corridor-contracts` and
`corridor-sdk`:

| idx | name | type | | idx | name | type |
|----:|------|------|-|----:|------|------|
| 0 | `corridor_id` | `Field` | | 5 | `issuer_id` | `Field` |
| 1 | `min_tier` | `u32` | | 6 | `min_cred_epoch` | `u64` |
| 2 | `now` | `u64` | | 7 | `auditor_pubkey` | `Field` |
| 3 | `nullifier` | `Field` | | 8 | `auditor_blob` | `Field` |
| 4 | `disclosed_tag` | `u32` | | | | |

**Private witness:** `holder_secret, tier, expiry, cred_epoch, salt,
issuer_pk_x, issuer_pk_y, sig_s_lo, sig_s_hi, sig_e_lo, sig_e_hi,
auditor_nonce`.

**`eligibility::check` asserts:**

1. `holder_binding = Poseidon2([holder_secret, salt])`
2. `statement = Poseidon2([holder_binding, tier, expiry, cred_epoch])`
3. `schnorr::verify_signature(pk, (s, e), statement)` — the issuer signed it
4. `Poseidon2([issuer_pk_x, issuer_pk_y]) == issuer_id`
5. `tier >= min_tier`
6. `expiry > now`
7. `cred_epoch >= min_cred_epoch` — bulk-revocation floor
8. `nullifier == Poseidon2([holder_secret, corridor_id])` — per corridor, unlinkable
9. `disclosed_tag < MAX_TAG` (16)
10. `auditor_blob == Poseidon2([auditor_pubkey, tier, issuer_id, nullifier, auditor_nonce])`

`issuer_id ∈ accepted_issuers` is checked **on Soroban** against the policy's
short allowlist, so the circuit stays fixed-size across corridors.

**Cost:** 73 ACIR opcodes (the Merkle-inclusion design was ~3200). See
[`docs/BENCHMARKS.md`](./docs/BENCHMARKS.md).

---

## Layout

```
corridor-circuits/
├── corridor_eligibility/
│   ├── Nargo.toml                       deps: noir-lang/poseidon v0.3.0, noir-lang/schnorr v0.4.0
│   ├── Prover.toml                      a valid witness (generated — see FIXTURES.md)
│   ├── FIXTURES.md
│   └── src/
│       ├── main.nr                      the `pub` I/O adapter over eligibility::check
│       ├── eligibility.nr               Public / Witness structs + check() + tests
│       ├── eligibility/fixture.nr       good() — a witness with a real SDK Grumpkin signature
│       ├── tags.nr                      DisclosureTag constants (mirrors the SDK)
│       └── conformance.nr               the pinned Poseidon2 vector
├── docs/                                CIRCUIT.md · BENCHMARKS.md · REVOCATION.md
├── Makefile / justfile
└── .tool-versions                       nargo 1.0.0-beta.26
```

---

## Build & test

**Prerequisite:** [`noirup`](https://noir-lang.org/docs/getting_started/quick_start),
then:

```bash
noirup --version 1.0.0-beta.26
cd corridor_eligibility

nargo fmt --check
nargo check                    # type-check
nargo test                     # 18 tests — every failure mode
nargo execute                  # solve the committed Prover.toml witness
nargo info                     # gate count → 73 ACIR opcodes

# or:
make test
```

### The fixture

`Prover.toml` and `src/eligibility/fixture.nr` carry a **real Grumpkin Schnorr
signature** produced by `corridor-sdk`. Regenerate after any change to the
statement layout or the signing scheme:

```bash
cd ../corridor-sdk && npm run gen-fixture -- --write
```

Nonces are derived deterministically (EdDSA-style), so an unchanged regeneration
is byte-identical. See [`corridor_eligibility/FIXTURES.md`](./corridor_eligibility/FIXTURES.md).

---

## Continuous integration

[`.github/workflows/ci.yml`](./.github/workflows/ci.yml) — every push and PR to
`main`:

| Job | Steps | Blocking |
|-----|-------|----------|
| **`check + fmt + test + execute`** | install Noir `1.0.0-beta.26` · `nargo fmt --check` · `nargo check` · `nargo test` (18) · `nargo execute` on the committed fixture · `nargo info` (prints the gate count) | ✅ required for merge |
| **`bb prove + verify`** | install Barretenberg, `bb prove` / `write_vk` / `verify` (UltraHonk) on the fixture | ⚠️ best-effort — `bb` has no released version mapped to beta.26 yet, so a tooling break emits a `::warning` rather than failing the build. A real proof failure still shows in the log. |

`main` is protected on the `check + fmt + test + execute` check.

---

## Conformance — the circuit ⇄ SDK ⇄ Soroban seam

Two hashes/schemes must agree bit-for-bit across three implementations, or
nothing verifies:

| | Circuit | SDK | Soroban |
|---|---|---|---|
| **Poseidon2** (`poseidon2([1,2]) == 0x038682…1ed7383`) | `conformance.nr` (`noir-lang/poseidon`) | `poseidon.test.ts` (`@zkpassport/poseidon2`) | `poseidon_conformance` (`rs-soroban-poseidon`) |
| **Grumpkin Schnorr** | `noir-lang/schnorr` v0.4.0 | `schnorr.ts` — pinned to that library's test vector | — (verified via the proof) |

CI's `nargo execute` on the SDK-signed fixture is the end-to-end check that the
SDK's signer and this circuit's verifier produce/accept the same signatures.

---

## Known gaps

- `auditor_blob` is a **hiding commitment, not encryption** — a warranted
  auditor can re-derive it over candidate values but cannot decrypt. In-circuit
  ECIES is milestone **M7**
  ([#3](https://github.com/Sconce-Labs/corridor-circuits/issues/3)).
- `bb prove/verify` in CI is best-effort until a `bb` release maps to beta.26
  ([#1](https://github.com/Sconce-Labs/corridor-circuits/issues/1)).
- **Targeted** single-credential revocation (an on-Stellar indexed Merkle tree)
  is designed in [`docs/REVOCATION.md`](./docs/REVOCATION.md) but deferred —
  short `expiry` + `min_cred_epoch` cover the pilot.

---

## Security

Not audited — see [`SECURITY.md`](./SECURITY.md). A constraint bug means fake
passes accepted on Stellar; the `eligibility.nr` failure-mode tests are the
guard, and every new constraint gets one. `holder_secret` **must** be generated
with a CSPRNG (issuer/holder tooling — audit finding H5).

---

## Contributing

[`CONTRIBUTING.md`](./CONTRIBUTING.md). Issues labelled `drips` are
reward-eligible through the
**[Stellar Drips Wave](https://www.drips.network/wave/stellar)**
([`DRIPS.md`](https://github.com/Sconce-Labs/corridor/blob/main/DRIPS.md)).

- `nargo test`, `nargo execute`, and `nargo fmt --check` must pass.
- A public-input layout change is a coordinated PR with `corridor-contracts`
  (+ `ABI.md`) and `corridor-sdk`; regenerate the fixture.
- Keep `conformance::PINNED` green and the Schnorr scheme matching `schnorr.ts`.

## License

[Apache-2.0](./LICENSE) · see [`NOTICE`](./NOTICE).
