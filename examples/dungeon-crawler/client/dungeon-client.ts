// dungeon-client.ts — Browser/Node client for Dungeon Crawler Arena
// Uses FCL for authentication and transaction submission

import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { randomBytes } from "crypto";

fcl.config()
  .put("accessNode.api", "https://rest-testnet.onflow.org")
  .put("discovery.wallet", "https://fcl-discovery.onflow.org/testnet/authn");

// Generate a cryptographically secure secret (never share until reveal)
export function generateSecret(): { secret: bigint; secretHex: string } {
  const bytes = randomBytes(32);
  const secretHex = bytes.toString("hex");
  const secret = BigInt("0x" + secretHex);
  return { secret, secretHex };
}

// Step 1: Commit — enter the dungeon
export async function enterDungeon(level: number): Promise<{ txId: string; secret: bigint }> {
  const { secret, secretHex } = generateSecret();

  // Store secret locally (localStorage in browser, file in Node)
  if (typeof window !== "undefined") {
    window.sessionStorage.setItem("dungeonSecret", secretHex);
  }

  const txId = await fcl.mutate({
    cadence: `
      import DungeonCrawler from 0xCONTRACT_ADDRESS
      transaction(secret: UInt256, level: UInt8) {
        prepare(signer: &Account) {}
        execute {
          DungeonCrawler.enterDungeon(player: self.address, secret: secret, level: level)
        }
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof import("@onflow/types")) => [
      arg(secret.toString(), t.UInt256),
      arg(level.toString(), t.UInt8),
    ],
    limit: 100,
  });

  await fcl.tx(txId).onceSealed();
  return { txId, secret };
}

// Step 2: Reveal — at least 1 block after commit
export async function revealDungeon(runId: number, secret: bigint): Promise<{ txId: string; won: boolean }> {
  const txId = await fcl.mutate({
    cadence: `
      import DungeonCrawler from 0xCONTRACT_ADDRESS
      import GameToken from 0xCONTRACT_ADDRESS
      transaction(runId: UInt64, secret: UInt256) {
        prepare(signer: auth(BorrowValue) &Account) {}
        execute {
          // Full transaction in reveal_combat_result.cdc
        }
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof import("@onflow/types")) => [
      arg(runId.toString(), t.UInt64),
      arg(secret.toString(), t.UInt256),
    ],
    limit: 200,
  });

  const sealed = await fcl.tx(txId).onceSealed();
  const resultEvent = sealed.events.find((e: any) => e.type.includes("DungeonResult"));
  const won = resultEvent?.data?.result === "1";
  return { txId, won };
}
