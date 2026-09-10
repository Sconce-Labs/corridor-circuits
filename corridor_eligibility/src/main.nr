//! Corridor eligibility circuit.
//!
//! Proves, without revealing the holder or their attributes, that:
//!   1. the holder owns a credential in the issuer set  (Merkle inclusion)
//!   2. that credential is not revoked                  (sparse-Merkle non-membership)
//!   3. its tier meets the corridor minimum
//!   4. it has not expired
//!   5. the per-corridor nullifier is correctly derived (unlinkable across corridors)
//!   6. the disclosed tag is a bounded enum index
//!   7. the auditor blob binds {tier, issuer, nullifier} under the auditor key
//!
//! The PUBLIC input order below is an ABI shared with `corridor-contracts`
//! (`PI_CREDENTIAL_ROOT = 0`, …). Changing the order here means changing the
//! `PI_*` constants and `ABI.md` there in the same coordinated PR.

use poseidon::poseidon2::Poseidon2;

global DEPTH: u32 = 32;
global MAX_TAG: u32 = 16;
/// Convention: an unfilled leaf in the revocation tree holds this value.
global EMPTY_LEAF: Field = 0;

fn hash2(a: Field, b: Field) -> Field {
    Poseidon2::hash([a, b], 2)
}

/// Recompute a Merkle root from a leaf, its sibling co-path, and the
/// left/right direction bits (bit = false → our node is the left child).
fn merkle_root_from(leaf: Field, siblings: [Field; DEPTH], index_bits: [bool; DEPTH]) -> Field {
    let mut node = leaf;
    for i in 0..DEPTH {
        let (l, r) = if index_bits[i] {
            (siblings[i], node)
        } else {
            (node, siblings[i])
        };
        node = hash2(l, r);
    }
    node
}

fn main(
    // ── PUBLIC — order must match corridor-contracts PI_* ─────────────────────
    credential_root: pub Field,
    revocation_root: pub Field,
    corridor_id: pub Field,
    min_tier: pub u32,
    now: pub u64,
    nullifier: pub Field,
    disclosed_tag: pub u32,
    issuer_id: pub Field,
    auditor_blob: pub Field,
    // ── PRIVATE witness ──────────────────────────────────────────────────────
    holder_secret: Field,
    tier: u32,
    expiry: u64,
    salt: Field,
    cred_siblings: [Field; DEPTH],
    cred_index_bits: [bool; DEPTH],
    rev_siblings: [Field; DEPTH],
    auditor_pk: Field,
    auditor_nonce: Field,
) {
    // 1. reconstruct the credential commitment
    let commitment =
        Poseidon2::hash([holder_secret, tier as Field, expiry as Field, issuer_id, salt], 5);

    // 2. credential inclusion under the issued-set root
    let cred_root = merkle_root_from(commitment, cred_siblings, cred_index_bits);
    assert(cred_root == credential_root, "credential not in issued set");

    // 3. revocation NON-membership: the sparse slot keyed by this commitment is
    //    still empty. The slot index is bound to the commitment so a prover
    //    cannot substitute a different empty slot.
    let rev_slot = Poseidon2::hash([commitment], 1);
    let rev_index_bits: [bool; DEPTH] = rev_slot.to_le_bits();
    let rev_root = merkle_root_from(EMPTY_LEAF, rev_siblings, rev_index_bits);
    assert(rev_root == revocation_root, "credential revoked");

    // 4. tier threshold
    assert(tier >= min_tier, "tier below corridor minimum");

    // 5. expiry
    assert(expiry > now, "credential expired");

    // 6. per-corridor nullifier
    let expected_nullifier = Poseidon2::hash([holder_secret, corridor_id], 2);
    assert(expected_nullifier == nullifier, "bad nullifier");

    // 7. disclosed tag is a bounded enum index (not free text)
    assert(disclosed_tag < MAX_TAG, "tag out of range");

    // 8. auditor blob binds the warrant-relevant fields under the auditor key.
    //    MVP: a hiding commitment. A later milestone swaps this for in-circuit
    //    ECIES so the auditor can actually decrypt {tier, issuer_id} for a
    //    flagged nullifier.
    let expected_blob =
        Poseidon2::hash([auditor_pk, tier as Field, issuer_id, nullifier, auditor_nonce], 5);
    assert(expected_blob == auditor_blob, "auditor blob mismatch");
}

#[test]
fn nullifier_is_deterministic() {
    let a = Poseidon2::hash([1, 2], 2);
    let b = Poseidon2::hash([1, 2], 2);
    assert(a == b);
}

#[test]
fn merkle_root_from_empty_path_folds_manually() {
    let leaf: Field = 7;
    let mut sib: [Field; DEPTH] = [0; DEPTH];
    sib[0] = 9;
    let bits: [bool; DEPTH] = [false; DEPTH];
    let root = merkle_root_from(leaf, sib, bits);

    let mut node = Poseidon2::hash([7, 9], 2);
    for _ in 1..DEPTH {
        node = Poseidon2::hash([node, 0], 2);
    }
    assert(root == node);
}
