# Revocation

**Option B has no revocation accumulator in this circuit.** Revocation is
handled two ways, both outside the circuit's Merkle machinery (which was
removed):

## 1. Short expiry (primary)

The circuit enforces `expiry > now`. Issuer statements are signed with a short
`expiry` (days). To revoke an individual holder, the issuer simply stops
re-signing. Zero on-chain revocation infrastructure.

## 2. Epoch floor (bulk)

Every statement carries a `cred_epoch`. The circuit enforces
`cred_epoch >= min_cred_epoch`, where `min_cred_epoch` is a public input the
Stellar contract binds to the corridor's policy.

- The issuer publishes a higher epoch on Midnight
  (`corridor.compact.bumpEpoch`).
- Corridor operators raise their policy floor on Stellar
  (`corridor_registry.set_min_cred_epoch`, monotonic).
- Every statement signed under an older epoch stops verifying.

This is a blunt instrument (it revokes a whole cohort), which is why short
expiry is primary.

## 3. Targeted revocation (designed, deferred)

A small **indexed Merkle tree on Stellar** (BN254/Poseidon2, same field as the
circuit) keyed by `Poseidon2(holder_binding)` or a per-statement id, with a
low-leaf non-membership proof added to the circuit. Not built — short expiry
covers the pilot. Design notes:

- Leaves `{ value, next_index, next_value }`, sorted linked list, sentinel
  `{0,0,0}`.
- Revoke = insert the key. Prove non-revocation = supply the low leaf `L`,
  prove `L` in the tree and `L.value < key < L.next_value` (or `L` is the tail).
- The tree lives in a Soroban contract so there is no cross-chain sync — one
  field, one chain.

Tracked at [#2](https://github.com/Sconce-Labs/corridor-circuits/issues/2).

---

## History

Earlier designs used a credential Merkle tree on Midnight with the root synced
to Stellar, and a revocation tree (first a sparse Merkle tree, then an indexed
Merkle tree). The audit found the sync could not work — Midnight is BLS12-381,
the circuit and Stellar are BN254, so the roots are values in different fields —
and that the sparse-tree check was a no-op. Option B removed all of it. See
[corridor/AUDIT.md](https://github.com/Sconce-Labs/corridor/blob/main/AUDIT.md)
C1/C4 and the IMT code in this repo's git history if targeted revocation is
revived.
