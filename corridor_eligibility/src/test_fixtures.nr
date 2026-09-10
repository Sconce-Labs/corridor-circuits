//! Deterministic test witnesses. Test-only — a real holder reads Merkle paths
//! from the Midnight indexer.

use crate::eligibility::{Public, Witness};
use crate::merkle::{DEPTH, EMPTY_LEAF, low_bits, root_from};
use poseidon::poseidon2::Poseidon2;

/// Holder at leaf index 0 of an otherwise-empty credential tree, with an empty
/// revocation tree. All roots are derived so `eligibility::check` accepts it.
pub fn good() -> (Public, Witness) {
    let issuer_id: Field = 7;
    let corridor_id: Field = 4;

    let w = Witness {
        holder_secret: 12345,
        tier: 3,
        expiry: 9_000_000,
        salt: 42,
        cred_siblings: [0; DEPTH],
        cred_index_bits: [false; DEPTH],
        rev_siblings: [0; DEPTH],
        auditor_pk: 0,
        auditor_nonce: 7,
    };

    let c = Poseidon2::hash(
        [w.holder_secret, w.tier as Field, w.expiry as Field, issuer_id, w.salt],
        5,
    );
    let cred_root = root_from(c, w.cred_siblings, w.cred_index_bits);
    let rev_slot = Poseidon2::hash([c], 1);
    let rev_root = root_from(EMPTY_LEAF, w.rev_siblings, low_bits(rev_slot));
    let nullifier = Poseidon2::hash([w.holder_secret, corridor_id], 2);
    let auditor_blob = Poseidon2::hash(
        [w.auditor_pk, w.tier as Field, issuer_id, nullifier, w.auditor_nonce],
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
        auditor_blob,
    };
    (p, w)
}
