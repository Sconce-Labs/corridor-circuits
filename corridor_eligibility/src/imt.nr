//! Indexed Merkle tree — non-membership by low-leaf range proof.
//!
//! Replaces the (unsound) sparse-position revocation check. An IMT stores
//! leaves `{ value, next_index, next_value }` as a sorted linked list by
//! `value`; empty leaves are all-zero. To prove `key` is NOT in the set, show
//! the "low leaf" `L` with `L.value < key` and (`key < L.next_value` or
//! `L.next_value == 0`), and that `L` is in the tree.
//!
//! Keys are Poseidon2 outputs truncated to 248 bits so they can be compared as
//! integers; collision probability for n entries is ~n²/2^249 (negligible), and
//! a collision in an IMT is a liveness issue (over-revocation), never a
//! soundness one.

use crate::merkle::{DEPTH, root_from};
use poseidon::poseidon2::Poseidon2;

pub struct LowLeaf {
    pub value: Field,
    pub next_index: Field,
    pub next_value: Field,
}

pub fn leaf_hash(l: LowLeaf) -> Field {
    Poseidon2::hash([l.value, l.next_index, l.next_value], 3)
}

/// Truncate a field element to its low 248 bits (31 bytes) so IMT keys are
/// order-comparable.
pub fn key_of(x: Field) -> Field {
    let be: [u8; 32] = x.to_be_bytes();
    let mut acc: Field = 0;
    // skip the top byte, fold the low 31 big-endian bytes
    for i in 1..32 {
        acc = acc * 256 + be[i] as Field;
    }
    acc
}

/// `a < b` for values known to be < 2^248. Total (never panics): if `a >= b`,
/// `b - a` wraps to ~2^254 and the high-bit check returns false. `|` in Noir is
/// not short-circuit, so callers must be able to call this with any ordering.
pub fn lt_248(a: Field, b: Field) -> bool {
    let diff = b - a;
    let bits: [bool; 254] = diff.to_le_bits();
    let mut fits = diff != 0;
    for i in 248..254 {
        fits = fits & !bits[i];
    }
    fits
}

/// Assert `key` is absent from the indexed Merkle tree rooted at `root`.
pub fn assert_non_membership(
    key: Field,
    low: LowLeaf,
    low_siblings: [Field; DEPTH],
    low_index_bits: [bool; DEPTH],
    root: Field,
) {
    // 1. the low leaf is in the tree
    let computed = root_from(leaf_hash(low), low_siblings, low_index_bits);
    assert(computed == root, "revocation proof: bad low-leaf path");

    // 2. low.value < key  (fails if key IS the low leaf, i.e. key is revoked)
    assert(lt_248(low.value, key), "credential revoked");

    // 3. key < low.next_value, unless low is the tail (next_value == 0)
    let is_tail = low.next_value == 0;
    assert(is_tail | lt_248(key, low.next_value), "credential revoked");
}

#[test]
fn key_of_is_the_low_31_bytes() {
    // 0x00..00_01_02 -> 0x0102
    let x: Field = 0x0102;
    assert(key_of(x) == 0x0102);
}

#[test]
fn lt_248_orders_small_values() {
    assert(lt_248(3, 7));
    assert(!lt_248(7, 7));
}

#[test(should_fail)]
fn lt_248_rejects_reversed() {
    assert(lt_248(7, 3));
}

#[test]
fn non_membership_of_a_key_between_two_leaves() {
    // tree = single low leaf {10, 0, 20}; prove key=15 is absent.
    let low = LowLeaf { value: 10, next_index: 0, next_value: 20 };
    let sibs: [Field; DEPTH] = [0; DEPTH];
    let bits: [bool; DEPTH] = [false; DEPTH];
    let root = root_from(leaf_hash(low), sibs, bits);
    assert_non_membership(15, low, sibs, bits, root);
}

#[test(should_fail_with = "credential revoked")]
fn membership_is_rejected() {
    // key == low.value  → "revoked"
    let low = LowLeaf { value: 15, next_index: 0, next_value: 20 };
    let sibs: [Field; DEPTH] = [0; DEPTH];
    let bits: [bool; DEPTH] = [false; DEPTH];
    let root = root_from(leaf_hash(low), sibs, bits);
    assert_non_membership(15, low, sibs, bits, root);
}
