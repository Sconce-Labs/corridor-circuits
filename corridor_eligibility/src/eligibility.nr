//! The eligibility check under the **issuer-signed statement** model
//! (corridor/docs/CREDENTIAL_ACCUMULATOR.md, Option B).
//!
//! There is no credential Merkle tree. A regulated issuer, after running KYC
//! once, signs `{ holder_binding, tier, expiry, cred_epoch }` with a Grumpkin
//! Schnorr key. The holder proves knowledge of a valid signature plus the
//! per-corridor predicates. Revocation is short `expiry` + the issuer bumping
//! `min_cred_epoch` (bulk); targeted revocation is a later add-on.

use poseidon::poseidon2::Poseidon2;
use schnorr::verify_signature;
use std::embedded_curve_ops::{EmbeddedCurvePoint, EmbeddedCurveScalar};

pub global MAX_TAG: u32 = 16;

pub struct Public {
    pub corridor_id: Field,
    pub min_tier: u32,
    pub now: u64,
    pub nullifier: Field,
    pub disclosed_tag: u32,
    /// `Poseidon2(issuer_pk.x, issuer_pk.y)` — the corridor policy's
    /// `accepted_issuers` are these ids.
    pub issuer_id: Field,
    /// Bulk-revocation floor, from the policy: credentials with a lower
    /// `cred_epoch` are rejected.
    pub min_cred_epoch: u64,
    /// Auditor key the blob binds to (`== policy.auditor_pubkey`; `0` = none).
    pub auditor_pubkey: Field,
    pub auditor_blob: Field,
}

pub struct Witness {
    pub holder_secret: Field,
    pub tier: u32,
    pub expiry: u64,
    pub cred_epoch: u64,
    pub salt: Field,
    // issuer Schnorr public key (Grumpkin point)
    pub issuer_pk_x: Field,
    pub issuer_pk_y: Field,
    // issuer signature over the statement: (s, e) as 128-bit limb pairs
    pub sig_s_lo: Field,
    pub sig_s_hi: Field,
    pub sig_e_lo: Field,
    pub sig_e_hi: Field,
    pub auditor_nonce: Field,
}

/// The holder-hiding binding the issuer signs over.
pub fn holder_binding(w: Witness) -> Field {
    Poseidon2::hash([w.holder_secret, w.salt], 2)
}

/// The exact message the issuer's Schnorr signature covers.
pub fn statement_message(w: Witness) -> Field {
    Poseidon2::hash(
        [holder_binding(w), w.tier as Field, w.expiry as Field, w.cred_epoch as Field],
        4,
    )
}

pub fn nullifier_of(secret: Field, corridor_id: Field) -> Field {
    Poseidon2::hash([secret, corridor_id], 2)
}

pub fn issuer_id_of(pk_x: Field, pk_y: Field) -> Field {
    Poseidon2::hash([pk_x, pk_y], 2)
}

pub fn auditor_blob_of(w: Witness, p: Public) -> Field {
    Poseidon2::hash(
        [p.auditor_pubkey, w.tier as Field, p.issuer_id, p.nullifier, w.auditor_nonce],
        5,
    )
}

/// All constraints. Panics (fails the proof) on any violation.
pub fn check(p: Public, w: Witness) {
    // 1. the issuer signed this exact credential statement
    let pk = EmbeddedCurvePoint::new(w.issuer_pk_x, w.issuer_pk_y);
    let sig = (
        EmbeddedCurveScalar::new(w.sig_s_lo, w.sig_s_hi),
        EmbeddedCurveScalar::new(w.sig_e_lo, w.sig_e_hi),
    );
    assert(verify_signature(pk, sig, statement_message(w)), "bad issuer signature");

    // 2. the public issuer id is this key (so the corridor's allowlist check bites)
    assert(issuer_id_of(w.issuer_pk_x, w.issuer_pk_y) == p.issuer_id, "issuer id mismatch");

    // 3/4. tier + expiry
    assert(w.tier >= p.min_tier, "tier below corridor minimum");
    assert(w.expiry > p.now, "credential expired");

    // 5. bulk revocation
    assert(w.cred_epoch >= p.min_cred_epoch, "credential epoch revoked");

    // 6. per-corridor nullifier
    assert(nullifier_of(w.holder_secret, p.corridor_id) == p.nullifier, "bad nullifier");

    // 7. bounded disclosure tag
    assert(p.disclosed_tag < MAX_TAG, "tag out of range");

    // 8. auditor blob binding
    assert(auditor_blob_of(w, p) == p.auditor_blob, "auditor blob mismatch");
}

mod fixture;

mod tests {
    use crate::eligibility::fixture::good;
    use super::{auditor_blob_of, check, issuer_id_of, nullifier_of, statement_message};

    #[test]
    fn accepts_a_well_formed_witness() {
        let (p, w) = good();
        check(p, w);
    }

    #[test(should_fail_with = "bad issuer signature")]
    fn rejects_a_forged_signature() {
        let (p, mut w) = good();
        w.sig_s_lo += 1;
        check(p, w);
    }

    #[test(should_fail_with = "bad issuer signature")]
    fn rejects_a_tampered_statement() {
        let (p, mut w) = good();
        w.tier += 1; // signature no longer covers this tier
        check(p, w);
    }

    #[test(should_fail_with = "issuer id mismatch")]
    fn rejects_a_public_issuer_id_that_is_not_the_key() {
        let (mut p, w) = good();
        p.issuer_id += 1;
        check(p, w);
    }

    #[test(should_fail_with = "tier below corridor minimum")]
    fn rejects_tier_below_minimum() {
        let (mut p, w) = good();
        p.min_tier = w.tier + 1;
        check(p, w);
    }

    #[test(should_fail_with = "credential expired")]
    fn rejects_expired_credential() {
        let (mut p, w) = good();
        p.now = w.expiry;
        check(p, w);
    }

    #[test(should_fail_with = "credential epoch revoked")]
    fn rejects_a_bulk_revoked_epoch() {
        let (mut p, w) = good();
        p.min_cred_epoch = w.cred_epoch + 1;
        check(p, w);
    }

    #[test(should_fail_with = "bad nullifier")]
    fn rejects_wrong_nullifier() {
        let (mut p, w) = good();
        p.nullifier += 1;
        check(p, w);
    }

    #[test(should_fail_with = "tag out of range")]
    fn rejects_out_of_range_tag() {
        let (mut p, w) = good();
        p.disclosed_tag = super::MAX_TAG;
        check(p, w);
    }

    #[test(should_fail_with = "auditor blob mismatch")]
    fn rejects_wrong_auditor_blob() {
        let (mut p, w) = good();
        p.auditor_blob += 1;
        check(p, w);
    }

    #[test]
    fn nullifier_is_unlinkable_across_corridors() {
        let (p, w) = good();
        assert(
            nullifier_of(w.holder_secret, p.corridor_id)
                != nullifier_of(w.holder_secret, p.corridor_id + 1),
        );
    }

    #[test]
    fn issuer_id_binds_both_coordinates() {
        let (_, w) = good();
        assert(
            issuer_id_of(w.issuer_pk_x, w.issuer_pk_y)
                != issuer_id_of(w.issuer_pk_y, w.issuer_pk_x),
        );
    }

    #[test]
    fn statement_message_changes_with_epoch() {
        let (_, w) = good();
        let mut w2 = w;
        w2.cred_epoch += 1;
        assert(statement_message(w) != statement_message(w2));
    }

    #[test]
    fn auditor_blob_binds_to_the_nullifier() {
        let (p, w) = good();
        let mut p2 = p;
        p2.nullifier += 1;
        assert(auditor_blob_of(w, p2) != auditor_blob_of(w, p));
    }
}
