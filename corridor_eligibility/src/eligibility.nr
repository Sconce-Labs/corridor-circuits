//! The eligibility check, factored out of `main` so it can be unit-tested with
//! good and bad witnesses.

use crate::imt::{assert_non_membership, key_of, LowLeaf};
use crate::merkle::{DEPTH, root_from};
use poseidon::poseidon2::Poseidon2;

pub global MAX_TAG: u32 = 16;

pub struct Public {
    pub credential_root: Field,
    pub revocation_root: Field,
    pub corridor_id: Field,
    pub min_tier: u32,
    pub now: u64,
    pub nullifier: Field,
    pub disclosed_tag: u32,
    pub issuer_id: Field,
    // the auditor key the blob is bound to — the Stellar contract checks this
    // equals the corridor policy's `auditor_pubkey`.
    pub auditor_pubkey: Field,
    pub auditor_blob: Field,
}

pub struct Witness {
    pub holder_secret: Field,
    pub tier: u32,
    pub expiry: u64,
    pub salt: Field,
    // credential inclusion path
    pub cred_siblings: [Field; DEPTH],
    pub cred_index_bits: [bool; DEPTH],
    // revocation NON-membership: the indexed-Merkle-tree low leaf for this
    // credential's revocation key, and its inclusion path.
    pub rev_low_value: Field,
    pub rev_low_next_index: Field,
    pub rev_low_next_value: Field,
    pub rev_low_siblings: [Field; DEPTH],
    pub rev_low_index_bits: [bool; DEPTH],
    pub auditor_nonce: Field,
}

pub fn commitment(p: Public, w: Witness) -> Field {
    Poseidon2::hash(
        [w.holder_secret, w.tier as Field, w.expiry as Field, p.issuer_id, w.salt],
        5,
    )
}

pub fn nullifier_of(secret: Field, corridor_id: Field) -> Field {
    Poseidon2::hash([secret, corridor_id], 2)
}

pub fn auditor_blob_of(w: Witness, p: Public) -> Field {
    Poseidon2::hash(
        [p.auditor_pubkey, w.tier as Field, p.issuer_id, p.nullifier, w.auditor_nonce],
        5,
    )
}

/// All eight constraints. Panics (fails the proof) on any violation.
pub fn check(p: Public, w: Witness) {
    let c = commitment(p, w);

    // 1/2. credential inclusion
    let cred_root = root_from(c, w.cred_siblings, w.cred_index_bits);
    assert(cred_root == p.credential_root, "credential not in issued set");

    // 3. revocation NON-membership — the revocation key `Poseidon2(commitment)`
    //    (truncated to 248 bits) is absent from the indexed Merkle tree.
    let rev_key = key_of(Poseidon2::hash([c], 1));
    assert_non_membership(
        rev_key,
        LowLeaf {
            value: w.rev_low_value,
            next_index: w.rev_low_next_index,
            next_value: w.rev_low_next_value,
        },
        w.rev_low_siblings,
        w.rev_low_index_bits,
        p.revocation_root,
    );

    // 4/5. tier + expiry
    assert(w.tier >= p.min_tier, "tier below corridor minimum");
    assert(w.expiry > p.now, "credential expired");

    // 6. per-corridor nullifier
    assert(nullifier_of(w.holder_secret, p.corridor_id) == p.nullifier, "bad nullifier");

    // 7. bounded disclosure tag
    assert(p.disclosed_tag < MAX_TAG, "tag out of range");

    // 8. auditor blob binding
    assert(auditor_blob_of(w, p) == p.auditor_blob, "auditor blob mismatch");
}

// ── tests ────────────────────────────────────────────────────────────────────

#[test]
fn accepts_a_well_formed_witness() {
    let (p, w) = crate::test_fixtures::good();
    check(p, w);
}

#[test(should_fail_with = "credential not in issued set")]
fn rejects_wrong_credential_root() {
    let (mut p, w) = crate::test_fixtures::good();
    p.credential_root = p.credential_root + 1;
    check(p, w);
}

#[test(should_fail_with = "revocation proof: bad low-leaf path")]
fn rejects_wrong_revocation_root() {
    let (mut p, w) = crate::test_fixtures::good();
    p.revocation_root = p.revocation_root + 1;
    check(p, w);
}

#[test(should_fail_with = "tier below corridor minimum")]
fn rejects_tier_below_minimum() {
    let (mut p, w) = crate::test_fixtures::good();
    p.min_tier = w.tier + 1;
    check(p, w);
}

#[test(should_fail_with = "credential expired")]
fn rejects_expired_credential() {
    let (mut p, w) = crate::test_fixtures::good();
    p.now = w.expiry;
    check(p, w);
}

#[test(should_fail_with = "bad nullifier")]
fn rejects_wrong_nullifier() {
    let (mut p, w) = crate::test_fixtures::good();
    p.nullifier = p.nullifier + 1;
    check(p, w);
}

#[test(should_fail_with = "tag out of range")]
fn rejects_out_of_range_tag() {
    let (mut p, w) = crate::test_fixtures::good();
    p.disclosed_tag = MAX_TAG;
    check(p, w);
}

#[test(should_fail_with = "auditor blob mismatch")]
fn rejects_wrong_auditor_blob() {
    let (mut p, w) = crate::test_fixtures::good();
    p.auditor_blob = p.auditor_blob + 1;
    check(p, w);
}

#[test]
fn nullifier_is_unlinkable_across_corridors() {
    let (p, w) = crate::test_fixtures::good();
    let n_a = nullifier_of(w.holder_secret, p.corridor_id);
    let n_b = nullifier_of(w.holder_secret, p.corridor_id + 1);
    assert(n_a != n_b);
}

#[test]
fn commitment_is_deterministic_and_holder_specific() {
    let (p, w) = crate::test_fixtures::good();
    let c1 = commitment(p, w);
    let c2 = commitment(p, w);
    assert(c1 == c2);

    let mut w2 = w;
    w2.holder_secret = w.holder_secret + 1;
    assert(commitment(p, w2) != c1);
}

#[test]
fn auditor_blob_binds_to_the_nullifier() {
    let (p, w) = crate::test_fixtures::good();
    let mut p2 = p;
    p2.nullifier = p.nullifier + 1;
    // a different nullifier ⇒ a different blob, so the pass can't be lifted
    assert(auditor_blob_of(w, p2) != auditor_blob_of(w, p));
}

#[test(should_fail_with = "credential revoked")]
fn rejects_a_revoked_credential() {
    // Build a revocation IMT whose low leaf for this credential's key has
    // `value == key` — i.e. the credential IS in the revoked set.
    let (mut p, mut w) = crate::test_fixtures::good();
    let c = commitment(p, w);
    let key = crate::imt::key_of(poseidon::poseidon2::Poseidon2::hash([c], 1));
    let sibs: [Field; crate::merkle::DEPTH] = [0; crate::merkle::DEPTH];
    let bits: [bool; crate::merkle::DEPTH] = [false; crate::merkle::DEPTH];
    let revoked_leaf = crate::imt::LowLeaf { value: key, next_index: 0, next_value: 0 };
    p.revocation_root = crate::merkle::root_from(crate::imt::leaf_hash(revoked_leaf), sibs, bits);
    w.rev_low_value = key;
    w.rev_low_next_index = 0;
    w.rev_low_next_value = 0;
    check(p, w);
}

#[test(should_fail_with = "credential revoked")]
fn rejects_key_above_the_low_leaf_range() {
    // low leaf {10, 0, 20} but the real key is > 20 and not the tail → the
    // holder is lying about which low leaf applies.
    let (mut p, mut w) = crate::test_fixtures::good();
    let sibs: [Field; crate::merkle::DEPTH] = [0; crate::merkle::DEPTH];
    let bits: [bool; crate::merkle::DEPTH] = [false; crate::merkle::DEPTH];
    let low = crate::imt::LowLeaf { value: 10, next_index: 1, next_value: 20 };
    p.revocation_root = crate::merkle::root_from(crate::imt::leaf_hash(low), sibs, bits);
    w.rev_low_value = 10;
    w.rev_low_next_index = 1;
    w.rev_low_next_value = 20;
    check(p, w);
}
