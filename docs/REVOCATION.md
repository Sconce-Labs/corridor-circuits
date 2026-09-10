# Revocation: sparse Merkle tree vs. indexed Merkle tree

Tracks [#2](https://github.com/Sconce-Labs/corridor-circuits/issues/2).

## Today — sparse Merkle tree (SMT)

- Fixed depth 32. Empty leaf value = `0`.
- A credential `c` maps to slot `low_bits(Poseidon2(c))` (low 32 bits).
- **Revoke:** issuer sets `revoked[slot] = 1` on Midnight.
- **Prove non-revocation:** show a Merkle path from `0` at `slot` to
  `revocation_root`. The slot is derived from `c` in-circuit, so it can't be
  swapped.

**Pros:** trivial to implement, O(depth) proof, matches the credential tree.
**Cons:**
- The 32-bit truncation means two distinct credentials can collide onto the
  same slot. At testnet scale (hundreds of credentials) `P(collision)` is
  ~2⁻²³ per pair — negligible, but not zero, and it grows with volume.
- A collision would let a revoked credential's slot be "un-revoked" by a
  colliding non-revoked one, or vice versa.

## Alternative — indexed Merkle tree (IMT)

Leaves are `(value, next_value, next_index)` sorted by `value`. Non-membership
of `x` is a **range proof**: show the leaf `l` with `l.value < x < l.next_value`.

**Pros:** no truncation, no collision, membership and non-membership share one
structure, widely used (Aztec, Semaphore v4).
**Cons:** more circuit logic (sorted-linked-list invariants), inserts touch two
leaves, needs an off-chain tree builder that matches the Compact contract.

## Recommendation

Ship the SMT for testnet + the pilot. Move to an IMT before mainnet, or before
a single corridor's credential count approaches ~2¹⁶. The circuit's
`root_from` / `low_bits` are already isolated in `merkle.nr`, so the swap is
contained.
