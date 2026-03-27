import "EmergencyPause"

// MerkleAllowlist: Whitelist addresses using a Merkle tree.
// Admin sets the root; users prove membership by providing a proof path.
// More gas-efficient than storing all addresses on-chain.
access(all) contract MerkleAllowlist {

    access(all) entitlement AllowlistAdmin

    access(all) var merkleRoot: [UInt8]   // 32 bytes
    access(all) var listName: String
    access(all) var claimed: {Address: Bool}
    access(all) let AdminStoragePath: StoragePath

    access(all) event RootUpdated(listName: String, newRoot: String)
    access(all) event ClaimVerified(addr: Address, listName: String)

    access(all) resource Admin {
        access(AllowlistAdmin) fun updateRoot(root: [UInt8], name: String) {
            pre { root.length == 32: "Merkle root must be 32 bytes" }
            MerkleAllowlist.merkleRoot = root
            MerkleAllowlist.listName = name
            // Reset claims when root changes
            MerkleAllowlist.claimed = {}
            emit RootUpdated(listName: name, newRoot: String.fromUTF8(root) ?? "")
        }
    }

    // Verify a Merkle proof that `addr` is in the allowlist
    // proof: array of 32-byte sibling hashes from leaf to root
    // pathIndices: 0 = left, 1 = right for each level
    access(all) fun verify(addr: Address, proof: [[UInt8]], pathIndices: [UInt8]): Bool {
        EmergencyPause.assertNotPaused()
        pre {
            proof.length == pathIndices.length: "Proof length mismatch"
            proof.length <= 32: "Proof depth exceeds max 32 levels (4B leaves)"
        }

        // Leaf = keccak256(abi.encodePacked(address))
        // In Cadence: hash the 8-byte address representation
        var addrBytes: [UInt8] = addr.toBytes()
        // Pad to 32 bytes (Ethereum-style left-padding with zeros)
        var leaf: [UInt8] = []
        var i = 0
        while i < 24 { leaf.append(0); i = i + 1 }
        leaf.appendAll(addrBytes)

        var computedHash = HashAlgorithm.KECCAK_256.hash(leaf)

        var level = 0
        while level < proof.length {
            let sibling = proof[level]
            pre { sibling.length == 32: "Sibling hash must be 32 bytes" }

            var combined: [UInt8] = []
            if pathIndices[level] == 0 {
                // current is left child
                combined.appendAll(computedHash)
                combined.appendAll(sibling)
            } else {
                // current is right child
                combined.appendAll(sibling)
                combined.appendAll(computedHash)
            }
            computedHash = HashAlgorithm.KECCAK_256.hash(combined)
            level = level + 1
        }

        return computedHash == MerkleAllowlist.merkleRoot
    }

    // Verify and record a one-time claim
    access(all) fun claim(addr: Address, proof: [[UInt8]], pathIndices: [UInt8]): Bool {
        EmergencyPause.assertNotPaused()
        assert(MerkleAllowlist.claimed[addr] == nil, message: "Already claimed")
        let valid = self.verify(addr: addr, proof: proof, pathIndices: pathIndices)
        if valid {
            MerkleAllowlist.claimed[addr] = true
            emit ClaimVerified(addr: addr, listName: MerkleAllowlist.listName)
        }
        return valid
    }

    init() {
        self.merkleRoot = []
        self.listName = "default"
        self.claimed = {}
        self.AdminStoragePath = /storage/MerkleAllowlistAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}
