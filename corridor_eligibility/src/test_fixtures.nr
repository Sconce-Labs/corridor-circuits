//! Deterministic test witnesses. Test-only — a real holder reads Merkle paths
//! from the credential accumulator (see corridor/docs/CREDENTIAL_ACCUMULATOR.md).

use crate::eligibility::{Public, Witness};
use crate::imt::leaf_hash;
use crate::imt::LowLeaf;
use crate::merkle::{DEPTH, root_from};
use poseidon::poseidon2::Poseidon2;

/// Holder at leaf index 0 of an otherwise-empty credential tree. The revocation
/// IMT holds only its sentinel leaf `{0,0,0}` (nothing revoked), so the low
/// leaf for any key is that sentinel (it is the tail: next_value == 0).
pub fn good() -> (Public, Witness) {
    let issuer_id: Field = 7;
    let corridor_id: Field = 4;

    let cred_siblings: [Field; DEPTH] = [0; DEPTH];
    let cred_index_bits: [bool; DEPTH] = [false; DEPTH];
    let rev_low_siblings: [Field; DEPTH] = [0; DEPTH];
    let rev_low_index_bits: [bool; DEPTH] = [false; DEPTH];

    let holder_secret: Field = 12345;
    let tier: u32 = 3;
    let expiry: u64 = 9_000_000;
    let salt: Field = 42;
    let auditor_pubkey: Field = 0;
    let auditor_nonce: Field = 7;

    let c = Poseidon2::hash(
        [holder_secret, tier as Field, expiry as Field, issuer_id, salt],
        5,
    );
    let cred_root = root_from(c, cred_siblings, cred_index_bits);

    // empty revocation IMT: one sentinel leaf {0,0,0} at index 0
    let sentinel = LowLeaf { value: 0, next_index: 0, next_value: 0 };
    let rev_root = root_from(leaf_hash(sentinel), rev_low_siblings, rev_low_index_bits);

    let nullifier = Poseidon2::hash([holder_secret, corridor_id], 2);
    let auditor_blob = Poseidon2::hash(
        [auditor_pubkey, tier as Field, issuer_id, nullifier, auditor_nonce],
        5,
    );

    let p = Public {
        credential_root: cred_root,
        revocation_root: rev_root,
        corridor_id,
        min_tier: 2,
        now: 1_000_000,
        nullifier,
        disclosed_tag: 2,
        issuer_id,
        auditor_pubkey,
        auditor_blob,
    };
    let w = Witness {
        holder_secret,
        tier,
        expiry,
        salt,
        cred_siblings,
        cred_index_bits,
        rev_low_value: 0,
        rev_low_next_index: 0,
        rev_low_next_value: 0,
        rev_low_siblings,
        rev_low_index_bits,
        auditor_nonce,
    };
    (p, w)
}
