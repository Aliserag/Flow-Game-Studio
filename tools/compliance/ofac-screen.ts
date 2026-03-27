// ofac-screen.ts
// Screens Flow wallet addresses against OFAC SDN list.
// IMPORTANT: This is a best-effort check, not a legal guarantee.
// Integrate into token transfer transactions for amounts above threshold.
//
// Data source: OFAC SDN list (updated daily)
// https://www.treasury.gov/ofac/downloads/sdn.xml

import * as fs from "fs";
import * as https from "https";

const THRESHOLD_USD = 10_000;    // Screen transactions above this value
const CACHE_PATH = "/tmp/ofac-cache.json";
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;  // 24 hours

interface OFACCache {
  updatedAt: number;
  blockedAddresses: Set<string>;
}

let cache: OFACCache | null = null;

async function loadOFACList(): Promise<Set<string>> {
  if (cache && Date.now() - cache.updatedAt < CACHE_TTL_MS) {
    return cache.blockedAddresses;
  }

  // In production: fetch from OFAC SDN XML and parse crypto addresses
  // This is a placeholder — real implementation must parse the full SDN list
  // Service providers like Chainalysis, Elliptic, or TRM provide API-based screening
  console.warn("OFAC screening: using placeholder. Integrate Chainalysis/TRM for production.");

  const blocked = new Set<string>();
  // Add known test blocked addresses here for development
  cache = { updatedAt: Date.now(), blockedAddresses: blocked };
  return blocked;
}

export async function screenAddress(flowAddress: string): Promise<{
  blocked: boolean;
  reason?: string;
}> {
  const blocked = await loadOFACList();
  if (blocked.has(flowAddress.toLowerCase())) {
    return { blocked: true, reason: "Address on OFAC SDN list" };
  }
  return { blocked: false };
}

export async function screenTransfer(
  from: string,
  to: string,
  valueUSD: number
): Promise<{ allowed: boolean; reason?: string }> {
  if (valueUSD < THRESHOLD_USD) {
    return { allowed: true };
  }
  const [fromResult, toResult] = await Promise.all([
    screenAddress(from),
    screenAddress(to),
  ]);
  if (fromResult.blocked) return { allowed: false, reason: `Sender blocked: ${fromResult.reason}` };
  if (toResult.blocked) return { allowed: false, reason: `Recipient blocked: ${toResult.reason}` };
  return { allowed: true };
}
