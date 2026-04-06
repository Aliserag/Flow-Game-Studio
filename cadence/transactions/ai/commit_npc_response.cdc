// commit_npc_response.cdc
// Game server calls this to commit an NPC response hash before showing it to the player.
// Signs as the game admin account.

import NPCDialogue from 0xNPC_DIALOGUE_ADDRESS

transaction(npcId: String, player: Address, responseHash: [UInt8]) {
    prepare(signer: auth(Storage) &Account) {
        let admin = signer.storage.borrow<auth(NPCDialogue.DialogueAdmin) &NPCDialogue.Admin>(
            from: NPCDialogue.AdminStoragePath
        ) ?? panic("No NPCDialogue admin found — are you signing as the game server account?")

        let interactionId = admin.commit(
            npcId: npcId,
            player: player,
            responseHash: responseHash
        )

        log("NPC dialogue committed with interactionId: ".concat(interactionId.toString()))
    }
}
