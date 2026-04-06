/// server.ts — Coin Flip sponsor service.
///
/// Acts as the fee payer for commit and reveal transactions so players
/// never need FLOW tokens.  In production, replace the emulator service
/// account with a dedicated payer account that holds real FLOW.
///
/// Security note: The private key here is the well-known emulator service
/// account key — safe to commit for local dev only.  In production, load
/// keys from environment variables or a secrets manager.
///
/// Endpoints:
///   POST /authorize  → returns { address, keyId } for FCL payer field
///   POST /sign       → signs a transaction envelope message
///   GET  /health     → liveness check
import express, { Request, Response } from "express"
import * as elliptic from "elliptic"
import { SHA3 } from "sha3"

// ---------------------------------------------------------------------------
// Config — emulator service account (safe for local dev)
// ---------------------------------------------------------------------------

const SERVICE_ADDRESS = "0xf8d6e0586b0a20c7"
const SERVICE_PRIVATE_KEY = "2eae2f31cb5b756151fa11d82949763b73e28b92f8cc26c97d5bf4620e60d8b6"
const SERVICE_KEY_ID = 0

// In production, load from env:
// const SERVICE_ADDRESS    = process.env.PAYER_ADDRESS   ?? ""
// const SERVICE_PRIVATE_KEY = process.env.PAYER_PRIVATE_KEY ?? ""

// ---------------------------------------------------------------------------
// Signing helper
// ---------------------------------------------------------------------------

function signWithKey(privateKeyHex: string, msgHex: string): string {
  const ec = new elliptic.ec("p256")
  const key = ec.keyFromPrivate(Buffer.from(privateKeyHex, "hex"))

  const sha3 = new SHA3(256)
  sha3.update(Buffer.from(msgHex, "hex"))
  const hash = sha3.digest()

  const sig = key.sign(hash)
  const r = sig.r.toArrayLike(Buffer, "be", 32)
  const s = sig.s.toArrayLike(Buffer, "be", 32)
  return Buffer.concat([r, s]).toString("hex")
}

// ---------------------------------------------------------------------------
// Express server
// ---------------------------------------------------------------------------

const app = express()
app.use(express.json())

// CORS — open for local dev; restrict in production.
app.use((_req: Request, res: Response, next: () => void) => {
  res.header("Access-Control-Allow-Origin", "*")
  res.header("Access-Control-Allow-Headers", "Content-Type")
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  next()
})

app.options("*", (_req: Request, res: Response) => {
  res.sendStatus(200)
})

/// Returns the sponsor's address and key ID.
/// The FCL client uses this to build the payer authorization.
app.post("/authorize", (_req: Request, res: Response) => {
  res.json({
    address: SERVICE_ADDRESS,
    keyId: SERVICE_KEY_ID,
  })
})

/// Signs a transaction message on behalf of the payer.
/// Body: { message: string } — hex-encoded transaction envelope.
app.post("/sign", (req: Request, res: Response) => {
  const { message } = req.body as { message?: string }
  if (!message || typeof message !== "string") {
    res.status(400).json({ error: "message is required" })
    return
  }

  try {
    const signature = signWithKey(SERVICE_PRIVATE_KEY, message)
    res.json({ signature })
  } catch (err) {
    console.error("[sponsor] Signing error:", err)
    res.status(500).json({ error: "Signing failed" })
  }
})

app.get("/health", (_req: Request, res: Response) => {
  res.json({ ok: true, address: SERVICE_ADDRESS })
})

const PORT = 3001
app.listen(PORT, () => {
  console.log(`[sponsor] Payer service running on http://localhost:${PORT}`)
  console.log(`[sponsor] Using address: ${SERVICE_ADDRESS}`)
  console.log(`[sponsor] NOTE: Uses emulator service key — safe for local dev only`)
})
