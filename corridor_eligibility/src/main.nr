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
//! (`PI_CREDENTIAL_ROOT = 0`, …). Changing the order means changing the `PI_*`
//! constants and `ABI.md` there in the same coordinated PR.

mod merkle;
mod eligibility;
mod tags;
mod test_fixtures;
mod conformance;

use eligibility::{Public, Witness};
use merkle::DEPTH;

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
    eligibility::check(
        Public {
            credential_root,
            revocation_root,
            corridor_id,
            min_tier,
            now,
            nullifier,
            disclosed_tag,
            issuer_id,
            auditor_blob,
        },
        Witness {
            holder_secret,
            tier,
            expiry,
            salt,
            cred_siblings,
            cred_index_bits,
            rev_siblings,
            auditor_pk,
            auditor_nonce,
        },
    );
}
