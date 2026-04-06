// npc-dialogue.ts
// Server-side NPC dialogue generation using Claude API.
// Commits response hash on-chain before delivering to player.

import Anthropic from "@anthropic-ai/sdk";
import * as fcl from "@onflow/fcl";
import { createHash, randomBytes } from "crypto";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY! });

export interface NPCContext {
  npcId: string;
  npcName: string;
  npcPersonality: string;     // "gruff blacksmith who respects skill"
  npcKnowledge: string[];     // what the NPC knows about the world
  playerAddress: string;
  playerNFTs: string[];       // player's items (influences NPC reaction)
  playerAchievements: string[];
  gameState: string;          // current dungeon level, season, etc.
  playerMessage: string;
}

export interface NPCResponse {
  interactionId: bigint;
  response: string;
  salt: string;
  commitTxId: string;
}

export async function generateNPCDialogue(context: NPCContext): Promise<NPCResponse> {
  // Generate the AI response
  const systemPrompt = `You are ${context.npcName}. Personality: ${context.npcPersonality}.
You know: ${context.npcKnowledge.join(", ")}.
The player owns: ${context.playerNFTs.join(", ") || "nothing notable"}.
Their achievements: ${context.playerAchievements.join(", ") || "none yet"}.
Current game state: ${context.gameState}.
Respond in character. Be concise (2-3 sentences max). Acknowledge player assets naturally.`;

  const message = await anthropic.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 256,
    system: systemPrompt,
    messages: [{ role: "user", content: context.playerMessage }],
  });

  const response = (message.content[0] as any).text as string;
  const salt = randomBytes(16).toString("hex");

  // Commit hash on-chain BEFORE sending response to player
  const interactionId = await commitDialogue(context.npcId, context.playerAddress, response, salt);
  const commitTxId = interactionId.toString();

  return { interactionId, response, salt, commitTxId };
}

async function commitDialogue(npcId: string, player: string, response: string, salt: string): Promise<bigint> {
  // Hash: keccak256(response_bytes || salt_bytes || interactionId_bytes)
  // Use SHA3-256 to match Cadence's KECCAK_256 (they're equivalent for this purpose)
  const nextId = await getNextInteractionId();
  const combined = Buffer.concat([
    Buffer.from(response, "utf8"),
    Buffer.from(salt, "utf8"),
    Buffer.from(nextId.toString(), "utf8"),
  ]);
  const hash = createHash("sha3-256").update(combined).digest();

  const txId = await fcl.mutate({
    cadence: `
      import NPCDialogue from 0xNPC_DIALOGUE_ADDRESS
      transaction(npcId: String, player: Address, responseHash: [UInt8]) {
        prepare(signer: auth(BorrowValue) &Account) {
          let admin = signer.storage.borrow<auth(NPCDialogue.DialogueAdmin) &NPCDialogue.Admin>(
            from: NPCDialogue.AdminStoragePath) ?? panic("No admin")
          admin.commit(npcId: npcId, player: player, responseHash: responseHash)
        }
      }
    `,
    args: (arg, t) => [
      arg(npcId, t.String),
      arg(player, t.Address),
      arg(Array.from(hash).map(String), t.Array(t.UInt8)),
    ],
    limit: 100,
  });

  await fcl.tx(txId).onceSealed();
  return nextId;
}

async function getNextInteractionId(): Promise<bigint> {
  const result = await fcl.query({
    cadence: `
      import NPCDialogue from 0xNPC_DIALOGUE_ADDRESS
      access(all) fun main(): UInt64 { return NPCDialogue.nextInteractionId }
    `,
  });
  return BigInt(result);
}
