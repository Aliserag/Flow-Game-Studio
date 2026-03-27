// NOTE: This is the legacy REST polling indexer (5s polling interval).
// For production use, prefer flow-indexer-streaming.ts which uses gRPC subscription
// for ~100ms latency and lower access node load.

import Database from "better-sqlite3";
import * as fs from "fs";

const ACCESS_NODE = process.env.FLOW_ACCESS_NODE ?? "https://rest-testnet.onflow.org";
const DB_PATH = process.env.INDEXER_DB ?? "./flow-events.sqlite";
const POLL_INTERVAL_MS = 5_000;
const BATCH_SIZE = 100;

// Event types to watch — replace CONTRACT_ADDRESS with deployed address
const WATCHED_EVENTS: string[] = [
  "A.CONTRACT_ADDRESS.GameNFT.NFTMinted",
  "A.CONTRACT_ADDRESS.GameNFT.NFTTransferred",
  "A.CONTRACT_ADDRESS.GameToken.TokensMinted",
  "A.CONTRACT_ADDRESS.GameToken.TokensTransferred",
  "A.CONTRACT_ADDRESS.Marketplace.Listed",
  "A.CONTRACT_ADDRESS.Marketplace.Purchased",
  "A.CONTRACT_ADDRESS.RandomVRF.Committed",
  "A.CONTRACT_ADDRESS.RandomVRF.Revealed",
  "A.CONTRACT_ADDRESS.Tournament.TournamentCreated",
  "A.CONTRACT_ADDRESS.Tournament.TournamentResolved",
];

const db = new Database(DB_PATH);
db.exec(fs.readFileSync(new URL("./schema.sql", import.meta.url).pathname, "utf8"));

async function fetchBlockRange(start: number, end: number): Promise<void> {
  for (const eventType of WATCHED_EVENTS) {
    const url = `${ACCESS_NODE}/v1/events?type=${encodeURIComponent(eventType)}&start_height=${start}&end_height=${end}`;
    let res: Response;
    try {
      res = await fetch(url);
    } catch (err) {
      console.error(`Fetch error for ${eventType}:`, err);
      continue;
    }
    if (!res.ok) continue;

    const json: any = await res.json();
    if (!Array.isArray(json)) continue;

    const insert = db.prepare(
      `INSERT OR IGNORE INTO raw_events(block_height,block_id,tx_id,event_type,event_index,payload)
       VALUES (?,?,?,?,?,?)`
    );

    for (const blockEvents of json) {
      for (const ev of blockEvents.events ?? []) {
        insert.run(
          Number(blockEvents.block_height),
          blockEvents.block_id,
          ev.transaction_id,
          ev.type,
          ev.event_index,
          JSON.stringify(ev.payload)
        );
        updateMaterializedViews(ev.type, ev.payload, Number(blockEvents.block_height));
      }
    }
  }
}

/**
 * Parse a Cadence-encoded field from the payload.
 * Flow event payloads use: { type: "Event", value: { fields: [{name, value: {type, value}}] } }
 */
function getField(payload: any, fieldName: string): string | null {
  const fields: any[] = payload?.value?.fields ?? [];
  const field = fields.find((f: any) => f.name === fieldName);
  return field?.value?.value ?? null;
}

function updateMaterializedViews(eventType: string, payload: any, blockHeight: number): void {
  if (eventType.endsWith(".GameNFT.NFTTransferred") || eventType.endsWith(".GameNFT.Transferred")) {
    const id = getField(payload, "id");
    const to = getField(payload, "to");
    const contractAddress = eventType.split(".")[1];
    if (id && to && contractAddress) {
      db.prepare(
        `INSERT INTO nft_ownership(nft_id,contract_address,owner_address,last_transfer_block)
         VALUES (?,?,?,?)
         ON CONFLICT(nft_id,contract_address)
         DO UPDATE SET owner_address=excluded.owner_address, last_transfer_block=excluded.last_transfer_block`
      ).run(Number(id), `0x${contractAddress}`, to, blockHeight);
    }
  }

  if (eventType.endsWith(".GameToken.TokensDeposited")) {
    const amount = getField(payload, "amount");
    const to = getField(payload, "to");
    const tokenContract = eventType.split(".").slice(0, 3).join(".");
    if (amount && to) {
      db.prepare(
        `INSERT INTO token_balances(account_address,token_contract,balance,last_update_block)
         VALUES (?,?,?,?)
         ON CONFLICT(account_address,token_contract)
         DO UPDATE SET balance=excluded.balance, last_update_block=excluded.last_update_block`
      ).run(to, tokenContract, amount, blockHeight);
    }
  }
}

async function getLatestBlockHeight(): Promise<number> {
  const res = await fetch(`${ACCESS_NODE}/v1/blocks?height=sealed`);
  if (!res.ok) throw new Error(`Failed to fetch latest block: ${res.status}`);
  const json: any = await res.json();
  // Response can be array or object depending on API version
  const block = Array.isArray(json) ? json[0] : json;
  return Number(block?.header?.height ?? 0);
}

async function runIndexer(): Promise<void> {
  console.log(`Flow indexer started.\n  DB: ${DB_PATH}\n  Node: ${ACCESS_NODE}`);
  while (true) {
    try {
      const state = db.prepare("SELECT last_indexed_block FROM indexer_state WHERE id=1").get() as any;
      const lastIndexed: number = state.last_indexed_block;
      const latest = await getLatestBlockHeight();

      if (latest > lastIndexed) {
        const end = Math.min(lastIndexed + BATCH_SIZE, latest);
        await fetchBlockRange(lastIndexed + 1, end);
        db.prepare("UPDATE indexer_state SET last_indexed_block=? WHERE id=1").run(end);
        console.log(`Indexed blocks ${lastIndexed + 1}–${end} (chain head: ${latest})`);
      }
    } catch (err) {
      console.error("Indexer error:", err);
    }
    await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
  }
}

runIndexer();
