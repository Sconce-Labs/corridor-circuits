//! Cross-implementation Poseidon2 conformance anchor.
//!
//! `poseidon2([1, 2])` must equal this exact value in the SDK
//! (`@zkpassport/poseidon2`) and on Soroban (`rs-soroban-poseidon`). If any of
//! the three drift, the Merkle roots on Midnight, in this circuit, and checked
//! on Stellar stop agreeing. See corridor-contracts/ABI.md "Hash conformance".

use poseidon::poseidon2::Poseidon2;

pub global PINNED: Field = 0x038682aa1cb5ae4e0a3f13da432a95c77c5c111f6f030faf9cad641ce1ed7383;

#[test]
fn poseidon2_of_1_2_matches_the_pinned_vector() {
    assert(Poseidon2::hash([1, 2], 2) == PINNED);
}

#[test]
fn poseidon2_is_order_sensitive() {
    assert(Poseidon2::hash([1, 2], 2) != Poseidon2::hash([2, 1], 2));
}

#[test]
fn poseidon2_arity_matters() {
    // 2-input vs 1-input hash of the same first element must differ, so the
    // commitment (5 inputs), nullifier (2) and rev-slot (1) can't be confused.
    assert(Poseidon2::hash([1, 2], 2) != Poseidon2::hash([1], 1));
}
