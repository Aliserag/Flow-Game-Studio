// sponsor-service.ts
// HTTP service that co-signs Flow transactions as the fee payer.
// Players submit their signed transaction (as authorizer), we add the payer signature.
//
// Flow transaction role separation:
//   proposer  = provides sequence number (usually same as authorizer)
//   payer     = pays FLOW fees (the studio — this service)
//   authorizer = provides account capabilities (the player)
//
// This service ONLY signs as payer — it does NOT have access to player accounts.

import express from "express";
import { checkRateLimit } from "./rate-limiter.js";
import * as fcl from "@onflow/fcl";

const SPONSOR_PRIVATE_KEY = process.env.SPONSOR_PRIVATE_KEY!;  // From secrets manager
const SPONSOR_ADDRESS = process.env.SPONSOR_ADDRESS!;
const PORT = process.env.PORT ?? 3001;

// Maximum FLOW fee per transaction (0.001 FLOW = 1 mF, typical game tx cost)
const MAX_FEE_UFIX64 = "0.001";

// Allowed transaction templates (whitelist to prevent abuse)
// Only transactions in this set can be sponsored
const ALLOWED_CADENCE_HASHES = new Set<string>([
  // Add SHA256 hashes of allowed Cadence template strings
  // Generate with: echo -n "$(cat tx.cdc)" | sha256sum
  "REPLACE_WITH_HASH_OF_enter_dungeon_cdc",
  "REPLACE_WITH_HASH_OF_commit_move_cdc",
  "REPLACE_WITH_HASH_OF_reveal_move_cdc",
  "REPLACE_WITH_HASH_OF_setup_collection_cdc",
]);

const app = express();
app.use(express.json());

// POST /sponsor
// Body: { playerAddress, cadenceHash, partiallySignedTxRLP }
// Returns: { fullySignedTxRLP } — player submits this to Flow
app.post("/sponsor", async (req, res) => {
  const { playerAddress, cadenceHash, partiallySignedTxRLP } = req.body;

  if (!playerAddress || !cadenceHash || !partiallySignedTxRLP) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  // Rate limit: 20 sponsored txs per player per hour
  const allowed = await checkRateLimit(playerAddress, 20, 3600);
  if (!allowed) {
    return res.status(429).json({ error: "Rate limit exceeded. Try again later." });
  }

  // Whitelist check — prevent sponsoring arbitrary transactions
  if (!ALLOWED_CADENCE_HASHES.has(cadenceHash)) {
    return res.status(403).json({ error: "Transaction template not approved for sponsorship" });
  }

  try {
    // Decode the partially signed transaction
    // Add payer signature from sponsor account
    // Return the fully signed transaction RLP for the player to submit

    // NOTE: Full implementation uses @onflow/sdk transaction encoding.
    // The player builds and signs as authorizer+proposer off-chain,
    // sends the RLP here, we sign as payer and return.

    const fullySignedTxRLP = await signAsPayer(partiallySignedTxRLP, SPONSOR_PRIVATE_KEY, SPONSOR_ADDRESS);
    res.json({ fullySignedTxRLP });
  } catch (err) {
    console.error("Sponsor error:", err);
    res.status(500).json({ error: "Failed to sponsor transaction" });
  }
});

async function signAsPayer(partialRLP: string, privateKey: string, address: string): Promise<string> {
  // Decode, add payer signature, re-encode
  // Uses @onflow/sdk RLP encoding and ECDSA P256 signing
  // Full implementation: https://developers.flow.com/concepts/transactions#payer
  throw new Error("Implement with @onflow/sdk RLP encoding — see docs/flow/sponsored-transactions.md");
}

app.listen(PORT, () => console.log(`Sponsor service running on port ${PORT}`));
