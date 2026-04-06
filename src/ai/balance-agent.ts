// balance-agent.ts
// Autonomous game economy monitoring agent.
// Queries the event indexer SQLite database and surfaces economic red flags.
// Intended to be run as a scheduled job (daily cron).

import Database from "better-sqlite3";
import * as fs from "fs";

const DB_PATH = process.env.INDEXER_DB ?? "./tools/indexer/flow-events.sqlite";

interface EconomyReport {
  date: string;
  redFlags: string[];
  metrics: Record<string, any>;
  proposalDrafts: string[];
}

export async function runEconomyMonitor(): Promise<EconomyReport> {
  if (!fs.existsSync(DB_PATH)) {
    console.log("Indexer DB not found — no data to analyze");
    return { date: new Date().toISOString(), redFlags: [], metrics: {}, proposalDrafts: [] };
  }

  const db = new Database(DB_PATH, { readonly: true });
  const report: EconomyReport = {
    date: new Date().toISOString(),
    redFlags: [],
    metrics: {},
    proposalDrafts: [],
  };

  // --- Metric 1: Token velocity (transactions per day, last 7 days) ---
  try {
    const velocityRows = db.prepare(`
      SELECT DATE(indexed_at) as day, COUNT(*) as tx_count
      FROM raw_events WHERE event_type LIKE '%GameToken%'
      GROUP BY day ORDER BY day DESC LIMIT 7
    `).all() as any[];
    report.metrics.tokenVelocity = velocityRows;
  } catch (e) {
    report.metrics.tokenVelocity = "unavailable";
  }

  // --- Metric 2: Marketplace volume (last 7 days) ---
  try {
    const volumeRows = db.prepare(`
      SELECT DATE(indexed_at) as day, COUNT(*) as sales_count
      FROM raw_events WHERE event_type LIKE '%ListingSold%'
      GROUP BY day ORDER BY day DESC LIMIT 7
    `).all() as any[];
    report.metrics.marketplaceVolume = volumeRows;

    // Red flag: volume drop >50% week-over-week
    if (volumeRows.length >= 2) {
      const recent = volumeRows[0]?.sales_count ?? 0;
      const prior = volumeRows[1]?.sales_count ?? 1;
      if (prior > 0 && recent / prior < 0.5) {
        report.redFlags.push(`Marketplace volume dropped ${Math.round((1 - recent/prior)*100)}% day-over-day`);
        report.proposalDrafts.push("PROPOSAL: Review marketplace fee — high fees may be suppressing volume");
      }
    }
  } catch (e) {
    report.metrics.marketplaceVolume = "unavailable";
  }

  // --- Metric 3: Staking participation ---
  try {
    const stakingRows = db.prepare(`
      SELECT COUNT(DISTINCT json_extract(payload,'$.staker')) as unique_stakers
      FROM raw_events WHERE event_type LIKE '%StakingPool.Staked%'
    `).get() as any;
    report.metrics.uniqueStakers = stakingRows?.unique_stakers ?? 0;
  } catch (e) {
    report.metrics.uniqueStakers = "unavailable";
  }

  db.close();

  // Save report
  const reportPath = `docs/economics/auto-audit-${new Date().toISOString().slice(0,10)}.md`;
  const reportMd = `# Economy Auto-Audit: ${report.date}

## Red Flags
${report.redFlags.length > 0 ? report.redFlags.map(f => `- ${f}`).join("\n") : "None detected."}

## Metrics
\`\`\`json
${JSON.stringify(report.metrics, null, 2)}
\`\`\`

## Governance Proposals
${report.proposalDrafts.length > 0 ? report.proposalDrafts.map(p => `- ${p}`).join("\n") : "None needed."}
`;

  fs.mkdirSync("docs/economics", { recursive: true });
  fs.writeFileSync(reportPath, reportMd);
  console.log(`Economy report written to ${reportPath}`);

  return report;
}

runEconomyMonitor().catch(console.error);
