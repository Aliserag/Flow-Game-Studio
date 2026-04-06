// flow-indexer-streaming.ts
// Replaces REST polling with gRPC event subscription.
// Uses @onflow/sdk subscribe() for real-time event streaming.
//
// Advantages over polling:
// - Events arrive within ~100ms of block sealing (vs 5s polling interval)
// - No missed blocks — subscription handles gap recovery
// - Lower access node load — one persistent connection vs repeated requests

import * as sdk from "@onflow/sdk";
import Database from "better-sqlite3";
import * as fs from "fs";

const ACCESS_NODE_GRPC = process.env.FLOW_ACCESS_GRPC ?? "access.devnet.nodes.onflow.org:9000";
const DB_PATH = process.env.INDEXER_DB ?? "./flow-events.sqlite";

const db = new Database(DB_PATH);
db.exec(fs.readFileSync("./schema.sql", "utf8"));

const WATCHED_EVENTS: string[] = [
  "A.CONTRACT_ADDRESS.GameNFT.NFTMinted",
  "A.CONTRACT_ADDRESS.GameNFT.NFTTransferred",
  "A.CONTRACT_ADDRESS.RandomVRF.CommitSubmitted",
  "A.CONTRACT_ADDRESS.RandomVRF.RevealCompleted",
  "A.CONTRACT_ADDRESS.Marketplace.ListingSold",
  "A.CONTRACT_ADDRESS.Tournament.PrizeDistributed",
  "A.CONTRACT_ADDRESS.StakingPool.RewardsDistributed",
];

const insert = db.prepare(
  `INSERT OR IGNORE INTO raw_events(block_height,block_id,tx_id,event_type,event_index,payload)
   VALUES (?,?,?,?,?,?)`
);

async function startStreamingIndexer(): Promise<void> {
  console.log(`Streaming indexer connecting to ${ACCESS_NODE_GRPC}`);

  // Get starting block from persisted state
  const state = db.prepare("SELECT last_indexed_block FROM indexer_state WHERE id=1").get() as any;
  const startBlock: number = state.last_indexed_block + 1;

  console.log(`Starting from block ${startBlock}`);

  // Subscribe to events for all watched types
  // @onflow/sdk subscribe returns an async iterator
  for (const eventType of WATCHED_EVENTS) {
    subscribeToEvent(eventType, startBlock);
  }
}

async function subscribeToEvent(eventType: string, startBlock: number): Promise<void> {
  while (true) {
    try {
      // sdk.subscribe returns an async generator of event messages
      const subscription = sdk.subscribe({
        topic: sdk.SubscriptionTopic.EVENTS,
        args: {
          eventTypes: [eventType],
          startBlockHeight: startBlock,
        },
        nodeUrl: `grpc+insecure://${ACCESS_NODE_GRPC}`,
      });

      for await (const message of subscription) {
        if (message.events) {
          for (const ev of message.events) {
            try {
              insert.run(
                Number(ev.blockHeight),
                ev.blockId,
                ev.transactionId,
                ev.type,
                ev.eventIndex,
                JSON.stringify(ev.payload)
              );
              db.prepare("UPDATE indexer_state SET last_indexed_block=MAX(last_indexed_block,?) WHERE id=1")
                .run(Number(ev.blockHeight));
            } catch (dbErr) {
              console.error("DB insert error:", dbErr);
            }
          }
        }
      }
    } catch (err) {
      console.error(`Stream error for ${eventType}, reconnecting in 3s:`, err);
      await new Promise((r) => setTimeout(r, 3_000));
    }
  }
}

startStreamingIndexer().catch(console.error);
