//! Disclosure tag — a bounded **category label** for the corridor, chosen by
//! the holder's app and published in the `PassRecord`.
//!
//! IMPORTANT: the circuit only range-checks the tag (`< MAX_TAG`). It carries
//! **no attestation** — it is not bound to the credential, the holder, or the
//! tier. Do not read `PassRecord.tag` as a verified attribute; it is a
//! convenience label for filtering/analytics. (Audit R2-H1: the earlier
//! `TIER_*_PASS` values were removed because nothing bound them to `w.tier`,
//! so a low-tier holder could publish a high-tier tag.)
//!
//! Mirrors `DisclosureTag` in `corridor-sdk`. Values `0..<MAX_TAG`.

pub global GENERIC: u32 = 0;
pub global REMITTANCE: u32 = 1;
pub global AID_DISBURSEMENT: u32 = 2;
pub global LENDING_POOL: u32 = 3;
pub global MERCHANT_SETTLEMENT: u32 = 4;
pub global PAYROLL: u32 = 5;

#[test]
fn all_tags_are_in_range() {
    assert(GENERIC < crate::eligibility::MAX_TAG);
    assert(REMITTANCE < crate::eligibility::MAX_TAG);
    assert(AID_DISBURSEMENT < crate::eligibility::MAX_TAG);
    assert(LENDING_POOL < crate::eligibility::MAX_TAG);
    assert(MERCHANT_SETTLEMENT < crate::eligibility::MAX_TAG);
    assert(PAYROLL < crate::eligibility::MAX_TAG);
}
