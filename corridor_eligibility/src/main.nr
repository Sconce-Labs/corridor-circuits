//! Corridor eligibility circuit — issuer-signed statement model
//! (corridor/docs/CREDENTIAL_ACCUMULATOR.md, Option B).
//!
//! Proves, without revealing the holder or their attributes, that:
//!   1. a regulated issuer signed this credential (Grumpkin Schnorr)
//!   2. the public `issuer_id` is that signing key
//!   3. tier meets the corridor minimum
//!   4. it has not expired
//!   5. its `cred_epoch` is at or above the corridor's revocation floor
//!   6. the per-corridor nullifier is correctly derived (unlinkable across corridors)
//!   7. the disclosed tag is a bounded enum index
//!   8. the auditor blob binds {tier, issuer, nullifier} under the policy's auditor key
//!
//! SECURITY: `holder_secret` blinds the commitment and derives the nullifier
//! (`Poseidon2(secret, corridor_id)`). A low-entropy secret is grindable — the
//! issuer/wallet MUST generate it with a CSPRNG (`corridor-sdk` `randomSecret()`).
//!
//! The PUBLIC input order below is an ABI shared with `corridor-contracts`
//! (`PI_*` in `crates/corridor_types`) and the SDK. A change is a coordinated
//! PR across all three plus `ABI.md`.

mod eligibility;
mod tags;
mod conformance;

use eligibility::{Public, Witness};

fn main(
    // ── PUBLIC — order must match corridor-contracts PI_* ─────────────────────
    corridor_id: pub Field,
    min_tier: pub u32,
    now: pub u64,
    nullifier: pub Field,
    disclosed_tag: pub u32,
    issuer_id: pub Field,
    min_cred_epoch: pub u64,
    auditor_pubkey: pub Field,
    auditor_blob: pub Field,
    // ── PRIVATE witness ──────────────────────────────────────────────────────
    holder_secret: Field,
    tier: u32,
    expiry: u64,
    cred_epoch: u64,
    salt: Field,
    issuer_pk_x: Field,
    issuer_pk_y: Field,
    sig_s_lo: Field,
    sig_s_hi: Field,
    sig_e_lo: Field,
    sig_e_hi: Field,
    auditor_nonce: Field,
) {
    eligibility::check(
        Public {
            corridor_id,
            min_tier,
            now,
            nullifier,
            disclosed_tag,
            issuer_id,
            min_cred_epoch,
            auditor_pubkey,
            auditor_blob,
        },
        Witness {
            holder_secret,
            tier,
            expiry,
            cred_epoch,
            salt,
            issuer_pk_x,
            issuer_pk_y,
            sig_s_lo,
            sig_s_hi,
            sig_e_lo,
            sig_e_hi,
            auditor_nonce,
        },
    );
}
