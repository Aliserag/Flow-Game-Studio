// NPCDialogue.cdc
// Provably fair NPC dialogue — commit response hash before player sees it.
// Prevents "AI behavior farming": player can't retry until they get a favorable NPC response.
//
// Verifiability model:
// 1. Game generates AI response for NPC interaction
// 2. Game commits hash(response + salt + interactionId) on-chain BEFORE showing player
// 3. Player sees the response
// 4. Player can verify: hash matches commitment -> response wasn't changed

import "EmergencyPause"

access(all) contract NPCDialogue {

    access(all) entitlement DialogueAdmin

    access(all) struct DialogueCommitment {
        access(all) let interactionId: UInt64
        access(all) let npcId: String
        access(all) let player: Address
        access(all) let responseHash: [UInt8]   // keccak256(response || salt || interactionId)
        access(all) let committedAtBlock: UInt64
        access(all) var revealed: Bool
        access(all) var revealedResponse: String  // optional: for full on-chain verifiability

        init(interactionId: UInt64, npcId: String, player: Address, responseHash: [UInt8]) {
            self.interactionId = interactionId; self.npcId = npcId; self.player = player
            self.responseHash = responseHash
            self.committedAtBlock = getCurrentBlock().height
            self.revealed = false; self.revealedResponse = ""
        }
    }

    access(all) var commitments: {UInt64: DialogueCommitment}
    access(all) var nextInteractionId: UInt64
    access(all) let AdminStoragePath: StoragePath

    access(all) event DialogueCommitted(interactionId: UInt64, npcId: String, player: Address, block: UInt64)
    access(all) event DialogueRevealed(interactionId: UInt64, response: String)

    access(all) resource Admin {
        // Game server calls this before showing the NPC response to the player
        access(DialogueAdmin) fun commit(npcId: String, player: Address, responseHash: [UInt8]): UInt64 {
            EmergencyPause.assertNotPaused()
            let id = NPCDialogue.nextInteractionId
            NPCDialogue.nextInteractionId = id + 1
            NPCDialogue.commitments[id] = DialogueCommitment(
                interactionId: id, npcId: npcId, player: player, responseHash: responseHash
            )
            emit DialogueCommitted(interactionId: id, npcId: npcId, player: player, block: getCurrentBlock().height)
            return id
        }

        // Optional: reveal full response on-chain for maximum verifiability
        access(DialogueAdmin) fun reveal(interactionId: UInt64, response: String, salt: String) {
            var commitment = NPCDialogue.commitments[interactionId] ?? panic("Not found")
            pre { !commitment.revealed: "Already revealed" }
            // Verify hash matches
            let combined = response.utf8.concat(salt.utf8).concat(interactionId.toString().utf8)
            let hash = HashAlgorithm.KECCAK_256.hash(combined)
            assert(hash == commitment.responseHash, message: "Response hash mismatch")
            commitment.revealed = true
            commitment.revealedResponse = response
            NPCDialogue.commitments[interactionId] = commitment
            emit DialogueRevealed(interactionId: interactionId, response: response)
        }
    }

    init() {
        self.commitments = {}
        self.nextInteractionId = 0
        self.AdminStoragePath = /storage/NPCDialogueAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}
