CREATE TABLE IF NOT EXISTS raw_events (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    block_height INTEGER NOT NULL,
    block_id     TEXT NOT NULL,
    tx_id        TEXT NOT NULL,
    event_type   TEXT NOT NULL,
    event_index  INTEGER NOT NULL,
    payload      TEXT NOT NULL,
    indexed_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tx_id, event_index)
);

CREATE INDEX IF NOT EXISTS idx_events_type  ON raw_events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_block ON raw_events(block_height);

CREATE TABLE IF NOT EXISTS nft_ownership (
    nft_id              INTEGER NOT NULL,
    contract_address    TEXT NOT NULL,
    owner_address       TEXT NOT NULL,
    last_transfer_block INTEGER,
    PRIMARY KEY (nft_id, contract_address)
);

CREATE TABLE IF NOT EXISTS token_balances (
    account_address   TEXT NOT NULL,
    token_contract    TEXT NOT NULL,
    balance           TEXT NOT NULL,
    last_update_block INTEGER,
    PRIMARY KEY (account_address, token_contract)
);

CREATE TABLE IF NOT EXISTS indexer_state (
    id                  INTEGER PRIMARY KEY CHECK (id = 1),
    last_indexed_block  INTEGER NOT NULL DEFAULT 0
);
INSERT OR IGNORE INTO indexer_state(id, last_indexed_block) VALUES (1, 0);
