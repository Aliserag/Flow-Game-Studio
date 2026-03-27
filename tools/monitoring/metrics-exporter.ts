// metrics-exporter.ts
// Exposes Prometheus metrics from the event indexer database.
// Scrape endpoint: GET /metrics
// Pairs with: alert-rules.yml (Prometheus Alertmanager)

import express from "express";
import Database from "better-sqlite3";

const DB_PATH = process.env.INDEXER_DB ?? "./flow-events.sqlite";
const PORT = process.env.METRICS_PORT ?? 9090;
const db = new Database(DB_PATH);

const app = express();

app.get("/metrics", (req, res) => {
  const lines: string[] = [];

  const gauge = (name: string, value: number, labels: Record<string, string> = {}) => {
    const labelStr = Object.entries(labels).map(([k,v]) => `${k}="${v}"`).join(",");
    lines.push(`${name}{${labelStr}} ${value}`);
  };

  try {
    // Indexer health
    const state = db.prepare("SELECT last_indexed_block FROM indexer_state WHERE id=1").get() as any;
    gauge("flow_indexer_last_block", state?.last_indexed_block ?? 0);

    // Event counts (last 24h)
    const eventCounts = db.prepare(`
      SELECT event_type, COUNT(*) as cnt FROM raw_events
      WHERE indexed_at > datetime('now', '-24 hours')
      GROUP BY event_type
    `).all() as any[];
    for (const row of eventCounts) {
      gauge("flow_events_24h", row.cnt, { event_type: row.event_type });
    }

    // Marketplace volume (last 24h)
    const marketVol = db.prepare(`
      SELECT COUNT(*) as sales FROM raw_events
      WHERE event_type LIKE '%ListingSold%' AND indexed_at > datetime('now', '-24 hours')
    `).get() as any;
    gauge("flow_marketplace_sales_24h", marketVol?.sales ?? 0);

    // NFT ownership distribution
    const nftCount = db.prepare("SELECT COUNT(*) as cnt FROM nft_ownership").get() as any;
    gauge("flow_nft_total_tracked", nftCount?.cnt ?? 0);

    // Token balance concentration (top 10% share)
    const balances = db.prepare(`
      SELECT CAST(balance AS REAL) as b FROM token_balances ORDER BY b DESC
    `).all() as any[];
    if (balances.length > 0) {
      const top10Pct = balances.slice(0, Math.ceil(balances.length * 0.1))
        .reduce((sum: number, r: any) => sum + r.b, 0) /
        balances.reduce((sum: number, r: any) => sum + r.b, 0) * 100;
      gauge("flow_token_top10pct_concentration", top10Pct);
    }

    // Staking participation
    const stakers = db.prepare(`
      SELECT COUNT(DISTINCT json_extract(payload, '$.staker')) as cnt
      FROM raw_events WHERE event_type LIKE '%StakingPool.Staked%'
    `).get() as any;
    gauge("flow_staking_participants", stakers?.cnt ?? 0);

    res.set("Content-Type", "text/plain; version=0.0.4");
    res.send(lines.join("\n") + "\n");
  } catch (err) {
    console.error("Metrics error:", err);
    res.status(500).send("# Error generating metrics\n");
  }
});

app.listen(PORT, () => console.log(`Metrics exporter on :${PORT}/metrics`));
