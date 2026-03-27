# Flow Event Indexer

A poll-based TypeScript indexer that reads game events from the Flow Access Node REST API
and persists them into a local SQLite database with materialized views for common queries.

---

## Architecture Overview

### Poll-Based vs. Streaming

The indexer uses a **poll-based** approach rather than a streaming subscription:

| Aspect | Poll-Based (this indexer) | Streaming (e.g., gRPC subscribe) |
|--------|--------------------------|----------------------------------|
| Implementation | Simple HTTP fetch loop | Persistent gRPC or WebSocket connection |
| Resilience | Stateless restarts; resumes from `last_indexed_block` | Must handle reconnect + replay logic |
| Latency | ~5 s per poll cycle | Near-realtime |
| Complexity | Low | High |
| Suitable for | Analytics, leaderboards, off-chain state mirrors | Real-time UI feeds, in-game triggers |

For a game studio backend the poll cadence (5 s default) is sufficient for leaderboards,
ownership lookups, and analytics dashboards. If you need sub-second event delivery,
see the [Scaling](#scaling-considerations) section.

### Data Flow

```
Flow Access Node (REST API)
        |
        |  GET /v1/events?type=...&start_height=N&end_height=M
        v
  flow-indexer.ts  (Node.js process)
        |
        |-- raw_events (append-only event log)
        |-- nft_ownership (materialized: current NFT owner per contract)
        |-- token_balances (materialized: current balance per account/token)
        |-- indexer_state (single-row cursor: last indexed block)
        v
  flow-events.sqlite  (SQLite file on disk)
```

The indexer is intentionally single-process and single-threaded. SQLite serialises
all writes, so no locking issues arise even if you add multiple event processors.

---

## Setup and Configuration

### Prerequisites

- Node.js 20+
- npm or pnpm

### Install Dependencies

```bash
cd tools/indexer
npm install
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLOW_ACCESS_NODE` | `https://rest-testnet.onflow.org` | Flow REST Access Node base URL |
| `INDEXER_DB` | `./flow-events.sqlite` | Path to SQLite database file |

For mainnet:

```bash
export FLOW_ACCESS_NODE=https://rest-mainnet.onflow.org
export INDEXER_DB=/var/data/flow-events-mainnet.sqlite
```

### Schema Initialisation

The schema is applied automatically on startup via `db.exec(schema.sql)`. All
`CREATE TABLE IF NOT EXISTS` statements are idempotent — safe to run repeatedly.

To inspect or reset the database manually:

```bash
sqlite3 ./flow-events.sqlite ".schema"
sqlite3 ./flow-events.sqlite "DELETE FROM indexer_state; INSERT INTO indexer_state VALUES (1,0);"
```

---

## Running the Indexer

### Locally (Development)

```bash
cd tools/indexer
npm run dev          # nodemon — restarts on file change
# or
npm run start        # one-shot start
```

The indexer will log progress to stdout:

```
Flow indexer started.
  DB: ./flow-events.sqlite
  Node: https://rest-testnet.onflow.org
Indexed blocks 12345001–12345101 (chain head: 12345800)
Indexed blocks 12345102–12345202 (chain head: 12345800)
...
```

### In Production (systemd)

Create `/etc/systemd/system/flow-indexer.service`:

```ini
[Unit]
Description=Flow Event Indexer
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/flow-game-studio/tools/indexer
ExecStart=/usr/bin/node --experimental-specifier-resolution=node dist/flow-indexer.js
Restart=always
RestartSec=10
Environment=FLOW_ACCESS_NODE=https://rest-mainnet.onflow.org
Environment=INDEXER_DB=/var/data/flow-events.sqlite

[Install]
WantedBy=multi-user.target
```

Build first:

```bash
cd tools/indexer
npm run build        # tsc — outputs to dist/
```

Then enable:

```bash
sudo systemctl enable --now flow-indexer
sudo journalctl -u flow-indexer -f
```

### In Production (Docker)

```dockerfile
FROM node:20-slim
WORKDIR /app
COPY tools/indexer/package*.json ./
RUN npm ci --omit=dev
COPY tools/indexer/ ./
RUN npm run build
CMD ["node", "dist/flow-indexer.js"]
```

Mount the SQLite file as a volume to persist state across container restarts:

```bash
docker run -d \
  -e FLOW_ACCESS_NODE=https://rest-mainnet.onflow.org \
  -e INDEXER_DB=/data/flow-events.sqlite \
  -v flow-data:/data \
  flow-indexer:latest
```

---

## How to Add New Event Types

### Step 1 — Register the Event Type

Open `tools/indexer/flow-indexer.ts` and add the fully-qualified event type to
`WATCHED_EVENTS`:

```typescript
const WATCHED_EVENTS: string[] = [
  // ... existing events ...
  "A.CONTRACT_ADDRESS.Crafting.ItemCrafted",
  "A.CONTRACT_ADDRESS.Crafting.RecipeUnlocked",
];
```

Replace `CONTRACT_ADDRESS` with the hex address where the contract is deployed
(without the `0x` prefix in the string, e.g. `"A.f8d6e0586b0a20c7.Crafting.ItemCrafted"`).

### Step 2 — Add a Materialized View Handler (Optional)

If the new event should update a derived table (ownership, balances, leaderboard),
add a branch in `updateMaterializedViews()`:

```typescript
if (eventType.endsWith(".Crafting.ItemCrafted")) {
  const itemId = getField(payload, "itemId");
  const crafter = getField(payload, "crafter");
  if (itemId && crafter) {
    db.prepare(`
      INSERT INTO crafting_history(item_id, crafter_address, block_height)
      VALUES (?, ?, ?)
    `).run(Number(itemId), crafter, blockHeight);
  }
}
```

### Step 3 — Add Schema (if needed)

Add the new table or index to `tools/indexer/schema.sql`:

```sql
CREATE TABLE IF NOT EXISTS crafting_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id         INTEGER NOT NULL,
    crafter_address TEXT NOT NULL,
    block_height    INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_crafting_crafter ON crafting_history(crafter_address);
```

### Step 4 — Restart

The indexer will pick up from `last_indexed_block` on restart, backfilling any
new event types it missed. If you need to reindex from genesis, reset the cursor:

```sql
UPDATE indexer_state SET last_indexed_block = 0 WHERE id = 1;
```

---

## Query Examples

Open a SQLite shell:

```bash
sqlite3 ./flow-events.sqlite
```

### NFTs Owned by an Address

```sql
SELECT nft_id, contract_address
FROM nft_ownership
WHERE owner_address = '0xabc123def456'
ORDER BY nft_id;
```

### Token Balance

```sql
SELECT balance
FROM token_balances
WHERE account_address = '0xabc123def456'
  AND token_contract LIKE '%GameToken%';
```

### Recent Marketplace Sales (Last 20)

```sql
SELECT block_height, tx_id, payload
FROM raw_events
WHERE event_type LIKE '%Marketplace.Purchased%'
ORDER BY block_height DESC
LIMIT 20;
```

### Parse a Cadence Payload in SQL (SQLite JSON Functions)

```sql
-- Extract the "price" field from a Purchased event payload
SELECT
  block_height,
  json_extract(payload, '$.value.fields[2].value.value') AS price
FROM raw_events
WHERE event_type LIKE '%Marketplace.Purchased%'
ORDER BY block_height DESC
LIMIT 10;
```

Note: field index positions depend on your contract's event definition. Use
`getField()` in TypeScript or query `raw_events` with `json_each()` for robust extraction.

### Events in a Block Range

```sql
SELECT event_type, COUNT(*) AS cnt
FROM raw_events
WHERE block_height BETWEEN 12000000 AND 12001000
GROUP BY event_type
ORDER BY cnt DESC;
```

### Leaderboard: Top NFT Holders

```sql
SELECT owner_address, COUNT(*) AS nft_count
FROM nft_ownership
WHERE contract_address = '0xf8d6e0586b0a20c7'
GROUP BY owner_address
ORDER BY nft_count DESC
LIMIT 10;
```

---

## Scaling Considerations

### SQLite Limits

SQLite handles millions of rows comfortably for read-heavy workloads. For a
game with active on-chain economy you may start hitting limits when:

- The `raw_events` table exceeds ~50 M rows
- Write throughput during chain-sync exceeds ~10k inserts/s
- You need concurrent write access from multiple processes

### PostgreSQL Migration Path

`schema.sql` is written to be mostly portable. Key changes for PostgreSQL:

| SQLite | PostgreSQL |
|--------|------------|
| `INTEGER PRIMARY KEY AUTOINCREMENT` | `BIGSERIAL PRIMARY KEY` |
| `INSERT OR IGNORE` | `INSERT ... ON CONFLICT DO NOTHING` |
| `ON CONFLICT(...) DO UPDATE` | Same syntax (supported since PG 9.5) |
| `DATETIME DEFAULT CURRENT_TIMESTAMP` | `TIMESTAMPTZ DEFAULT now()` |

Replace `better-sqlite3` with `pg` or `postgres` and wrap the schema exec in a
migration tool (e.g., `node-pg-migrate`, `Flyway`).

### Parallelising Event Fetching

The current loop fetches one event type at a time sequentially. For faster
catch-up during initial sync, parallelise the fetch loop:

```typescript
await Promise.all(
  WATCHED_EVENTS.map(eventType => fetchSingleEventType(eventType, start, end))
);
```

Use a write queue (e.g., `p-limit`) to serialise SQLite inserts.

### Near-Realtime Delivery

For sub-second event delivery to game clients, add a pub/sub layer on top of
the indexer's SQLite writes:

1. After each successful insert, publish to Redis Streams or NATS
2. Game server subscribes and pushes to connected clients via WebSocket
3. The indexer remains the source of truth; the message broker is the delivery channel

### Horizontal Scaling

To run multiple indexer replicas (e.g., one per contract family):

1. Shard `WATCHED_EVENTS` across processes
2. Use a shared PostgreSQL database instead of per-process SQLite
3. Use advisory locks or a distributed cursor table to prevent overlapping block ranges
