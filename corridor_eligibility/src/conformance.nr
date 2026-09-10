//! Cross-implementation Poseidon2 conformance anchor.
//!
//! Every Poseidon2 output the circuit produces must be byte-identical in the
//! SDK (`@zkpassport/poseidon2`) and on Soroban (`rs-soroban-poseidon`), or the
//! issuer signature, nullifier and auditor blob computed here and re-derived
//! elsewhere stop agreeing. The circuit uses these arities:
//!
//!   * 2 — `holder_binding`, `issuer_id`, `nullifier`
//!   * 4 — `statement_message` (the signed message)
//!   * 5 — `auditor_blob`
//!
//! so all three are pinned below. See corridor-contracts/ABI.md "Hash
//! conformance"; the identical values are asserted in
//! corridor-sdk/src/poseidon.test.ts and
//! corridor-contracts/crates/poseidon_conformance.

use poseidon::poseidon2::Poseidon2;

pub global PINNED: Field = 0x038682aa1cb5ae4e0a3f13da432a95c77c5c111f6f030faf9cad641ce1ed7383;
pub global PINNED_4: Field = 0x130bf204a32cac1f0ace56c78b731aa3809f06df2731ebcf6b3464a15788b1b9;
pub global PINNED_5: Field = 0x2247be7014a54d17342a7ef677f58d28877780d203860396967f5d0a18d259db;

#[test]
fn poseidon2_of_1_2_matches_the_pinned_vector() {
    assert(Poseidon2::hash([1, 2], 2) == PINNED);
}

#[test]
fn poseidon2_of_1_2_3_4_matches_the_pinned_vector() {
    assert(Poseidon2::hash([1, 2, 3, 4], 4) == PINNED_4);
}

#[test]
fn poseidon2_of_1_2_3_4_5_matches_the_pinned_vector() {
    assert(Poseidon2::hash([1, 2, 3, 4, 5], 5) == PINNED_5);
}

#[test]
fn poseidon2_is_order_sensitive() {
    assert(Poseidon2::hash([1, 2], 2) != Poseidon2::hash([2, 1], 2));
}

#[test]
fn poseidon2_arity_matters() {
    // The same leading elements at different arities must not collide, so the
    // statement message (4), auditor blob (5) and nullifier (2) can't be confused.
    assert(Poseidon2::hash([1, 2], 2) != Poseidon2::hash([1], 1));
    assert(Poseidon2::hash([1, 2, 3, 4], 4) != Poseidon2::hash([1, 2, 3, 4, 5], 5));
}
