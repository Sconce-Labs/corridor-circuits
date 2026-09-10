//! Disclosure tag enum — a bounded index the holder chooses to publish.
//! Mirrors `DisclosureTag` in `corridor-sdk`. Values 0..<MAX_TAG.

pub global GENERIC: u32 = 0;
pub global TIER_1_PASS: u32 = 1;
pub global TIER_2_PASS: u32 = 2;
pub global TIER_3_PASS: u32 = 3;
pub global AID_DISBURSEMENT: u32 = 4;
pub global REMITTANCE: u32 = 5;
pub global LENDING_POOL: u32 = 6;

#[test]
fn all_tags_are_in_range() {
    assert(GENERIC < crate::eligibility::MAX_TAG);
    assert(TIER_1_PASS < crate::eligibility::MAX_TAG);
    assert(TIER_2_PASS < crate::eligibility::MAX_TAG);
    assert(TIER_3_PASS < crate::eligibility::MAX_TAG);
    assert(AID_DISBURSEMENT < crate::eligibility::MAX_TAG);
    assert(REMITTANCE < crate::eligibility::MAX_TAG);
    assert(LENDING_POOL < crate::eligibility::MAX_TAG);
}
