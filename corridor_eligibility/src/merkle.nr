//! Merkle helpers shared by the eligibility circuit.

use poseidon::poseidon2::Poseidon2;

pub global DEPTH: u32 = 32;
/// An unfilled leaf in the (sparse) revocation tree holds this value.
pub global EMPTY_LEAF: Field = 0;

pub fn hash2(a: Field, b: Field) -> Field {
    Poseidon2::hash([a, b], 2)
}

/// Recompute a Merkle root from a leaf, its sibling co-path, and the
/// left/right direction bits (bit = false → our node is the left child).
pub fn root_from(leaf: Field, siblings: [Field; DEPTH], index_bits: [bool; DEPTH]) -> Field {
    let mut node = leaf;
    for i in 0..DEPTH {
        let (l, r) = if index_bits[i] {
            (siblings[i], node)
        } else {
            (node, siblings[i])
        };
        node = hash2(l, r);
    }
    node
}

/// Low `DEPTH` bits of a field element, little-endian — the sparse slot index
/// for a commitment in the revocation tree.
pub fn low_bits(x: Field) -> [bool; DEPTH] {
    let all: [bool; 254] = x.to_le_bits();
    let mut out: [bool; DEPTH] = [false; DEPTH];
    for i in 0..DEPTH {
        out[i] = all[i];
    }
    out
}

#[test]
fn empty_path_folds_manually() {
    let leaf: Field = 7;
    let mut sib: [Field; DEPTH] = [0; DEPTH];
    sib[0] = 9;
    let bits: [bool; DEPTH] = [false; DEPTH];
    let root = root_from(leaf, sib, bits);

    let mut node = hash2(7, 9);
    for _ in 1..DEPTH {
        node = hash2(node, 0);
    }
    assert(root == node);
}

#[test]
fn right_child_swaps_the_pair() {
    let sib: [Field; DEPTH] = [3; DEPTH];
    let mut bits: [bool; DEPTH] = [false; DEPTH];
    bits[0] = true; // leaf is the right child at level 0
    let root = root_from(5, sib, bits);

    let mut node = hash2(3, 5); // sibling on the left
    for _ in 1..DEPTH {
        node = hash2(node, 3);
    }
    assert(root == node);
}

#[test]
fn low_bits_are_little_endian() {
    let bits = low_bits(11); // 0b1011
    assert(bits[0]);
    assert(bits[1]);
    assert(!bits[2]);
    assert(bits[3]);
}
