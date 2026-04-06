import './style.css'
/// main.ts — Coin Flip on Flow — UI logic.
///
/// Flow:
///   1. Connect wallet via FCL.
///   2. Choose Heads or Tails.
///   3. "Flip!" → commitFlip() — generates secret, computes hash, submits tx.
///   4. After seal, "Reveal!" → revealFlip() — submits secret, reads result.
///   5. Display flip history from get_all_flips.cdc script.
import "./fcl-config.js"
import * as fcl from "@onflow/fcl"
import * as t from "@onflow/types"
import { sha3_256 } from "@noble/hashes/sha3"
import { bytesToHex } from "@noble/hashes/utils"
import { sponsoredMutate } from "./sponsorship.js"

// ---------------------------------------------------------------------------
// Cadence source strings
// ---------------------------------------------------------------------------

const COMMIT_TX = `
import CoinFlip from 0xCoinFlip

transaction(commitHashHex: String, playerChoice: Bool) {
    prepare(signer: &Account) {
        let hashBytes = commitHashHex.decodeHex()
        let flipId = CoinFlip.commit(
            player: signer.address,
            commitHash: hashBytes,
            playerChoice: playerChoice
        )
        log("Committed flip #".concat(flipId.toString()))
    }
}
`

const REVEAL_TX = `
import CoinFlip from 0xCoinFlip

transaction(flipId: UInt64, secret: UInt256) {
    prepare(signer: &Account) {
        let won = CoinFlip.reveal(
            player: signer.address,
            flipId: flipId,
            secret: secret
        )
        log(won ? "You won!" : "Better luck next time.")
    }
}
`

const GET_ALL_FLIPS_SCRIPT = `
import CoinFlip from 0xCoinFlip
access(all) fun main(player: Address): {UInt64: CoinFlip.Commit} {
    return CoinFlip.getFlipsForPlayer(player: player)
}
`

// ---------------------------------------------------------------------------
// DOM helpers — safe element builders (no innerHTML on untrusted content)
// ---------------------------------------------------------------------------

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Partial<Record<string, string>> = {},
  ...children: (Node | string)[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag)
  for (const [k, v] of Object.entries(attrs)) {
    if (v !== undefined) node.setAttribute(k, v)
  }
  for (const child of children) {
    node.append(typeof child === "string" ? document.createTextNode(child) : child)
  }
  return node
}

// ---------------------------------------------------------------------------
// DOM refs
// ---------------------------------------------------------------------------

const connectBtn = document.getElementById("connect-btn")    as HTMLButtonElement
const walletAddr = document.getElementById("wallet-address") as HTMLSpanElement
const gameSect   = document.getElementById("game-section")   as HTMLDivElement
const flipBtn    = document.getElementById("flip-btn")       as HTMLButtonElement
const resultDiv  = document.getElementById("result")         as HTMLDivElement
const historyDiv = document.getElementById("history")        as HTMLDivElement
const coinEl     = document.getElementById("coin")           as HTMLDivElement

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let currentUser: { addr: string } | null = null
let pendingFlipId: number | null = null

function storeSecret(flipId: number, secret: bigint): void {
  const key = `coinflip:secret:${currentUser?.addr}:${flipId}`
  localStorage.setItem(key, secret.toString())
}

function loadSecret(flipId: number): bigint | null {
  const key = `coinflip:secret:${currentUser?.addr}:${flipId}`
  const val = localStorage.getItem(key)
  return val ? BigInt(val) : null
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

fcl.currentUser.subscribe((user: { addr?: string; loggedIn?: boolean }) => {
  if (user.loggedIn && user.addr) {
    currentUser = { addr: user.addr }
    walletAddr.textContent = user.addr
    connectBtn.textContent = "Disconnect"
    gameSect.style.display = "block"
    void refreshHistory()
  } else {
    currentUser = null
    walletAddr.textContent = ""
    connectBtn.textContent = "Connect Wallet"
    gameSect.style.display = "none"
  }
})

connectBtn.addEventListener("click", () => {
  if (currentUser) {
    fcl.unauthenticate()
  } else {
    void fcl.authenticate()
  }
})

// ---------------------------------------------------------------------------
// Commit
// ---------------------------------------------------------------------------

async function commitFlip(choice: boolean): Promise<void> {
  if (!currentUser) return

  const secretBytes = crypto.getRandomValues(new Uint8Array(32))

  const addrBytes = new TextEncoder().encode(currentUser.addr)
  const hashInput = new Uint8Array(secretBytes.length + addrBytes.length)
  hashInput.set(secretBytes, 0)
  hashInput.set(addrBytes, secretBytes.length)
  const commitHash = sha3_256(hashInput)
  const commitHashHex = bytesToHex(commitHash)

  let secretInt = BigInt(0)
  for (const byte of secretBytes) {
    secretInt = (secretInt << BigInt(8)) | BigInt(byte)
  }

  setResult("Submitting commit…")
  coinEl.classList.add("flipping")

  try {
    const txId = await sponsoredMutate({
      cadence: COMMIT_TX,
      args: (arg, t) => [
        arg(commitHashHex, t.String),
        arg(choice, t.Bool),
      ],
    })

    setResult("Commit submitted — waiting for seal…")
    const { events } = await fcl.tx(txId).onceSealed()

    const commitEvent = events.find((e: { type: string }) =>
      e.type.includes("FlipCommitted")
    )
    if (commitEvent) {
      const data = (commitEvent as { data: Record<string, string> }).data
      const flipId = Number(data["flipId"])
      storeSecret(flipId, secretInt)
      pendingFlipId = flipId
      setResult(
        `Committed flip #${flipId} at block ${data["commitBlockHeight"]}. Wait 1 block, then click Reveal!`
      )
      flipBtn.textContent = `Reveal Flip #${flipId}`
      flipBtn.dataset["mode"] = "reveal"
    }
  } catch (err) {
    console.error(err)
    setResult("Commit failed — check console.")
  } finally {
    coinEl.classList.remove("flipping")
  }

  void refreshHistory()
}

// ---------------------------------------------------------------------------
// Reveal
// ---------------------------------------------------------------------------

async function revealFlip(flipId: number): Promise<void> {
  if (!currentUser) return

  const secret = loadSecret(flipId)
  if (secret === null) {
    setResult("Secret not found in localStorage — cannot reveal.")
    return
  }

  setResult("Revealing…")
  coinEl.classList.add("flipping")

  try {
    const txId = await sponsoredMutate({
      cadence: REVEAL_TX,
      args: (arg, t) => [
        arg(String(flipId), t.UInt64),
        arg(secret.toString(), t.UInt256),
      ],
    })

    await fcl.tx(txId).onceSealed()

    const flips = await queryAllFlips(currentUser.addr)
    const flip = flips[flipId]
    if (flip?.isResolved) {
      const resultLabel = flip.result ? "HEADS" : "TAILS"
      const choiceLabel = flip.playerChoice ? "HEADS" : "TAILS"
      const wonLabel    = flip.won ? "WON" : "LOST"
      coinEl.textContent = flip.result ? "🪙" : "🔵"
      setResult(`${wonLabel}! Result: ${resultLabel} — You chose ${choiceLabel}`, flip.won ? "win" : "lose")
    }
  } catch (err) {
    console.error(err)
    setResult("Reveal failed — check console.")
  } finally {
    coinEl.classList.remove("flipping")
    flipBtn.textContent = "Flip!"
    delete flipBtn.dataset["mode"]
    pendingFlipId = null
    void refreshHistory()
  }
}

// ---------------------------------------------------------------------------
// Flip button
// ---------------------------------------------------------------------------

flipBtn.addEventListener("click", () => {
  if (flipBtn.dataset["mode"] === "reveal" && pendingFlipId !== null) {
    void revealFlip(pendingFlipId)
    return
  }
  const choiceEl = document.querySelector<HTMLInputElement>('input[name="choice"]:checked')
  const choice = choiceEl?.value === "heads"
  void commitFlip(choice)
})

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

interface FlipCommit {
  commitBlockHeight: string
  isResolved: boolean
  result: boolean | null
  playerChoice: boolean
  won: boolean | null
}

async function queryAllFlips(addr: string): Promise<Record<number, FlipCommit>> {
  const result = await fcl.query({
    cadence: GET_ALL_FLIPS_SCRIPT,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    args: (arg: (v: unknown, x: unknown) => unknown, fclT: any) => [arg(addr, fclT.Address)],
  })
  return result as Record<number, FlipCommit>
}

async function refreshHistory(): Promise<void> {
  if (!currentUser) return
  try {
    const flips = await queryAllFlips(currentUser.addr)
    const ids = Object.keys(flips).map(Number).sort((a, b) => b - a)

    // Clear and rebuild using safe DOM methods (no innerHTML on untrusted data).
    while (historyDiv.firstChild) historyDiv.removeChild(historyDiv.firstChild)

    if (ids.length === 0) {
      historyDiv.appendChild(
        el("p", { style: "color:#666" }, "No flips yet.")
      )
      return
    }

    historyDiv.appendChild(el("h3", { class: "history-title" }, "Flip History"))

    for (const id of ids) {
      const f = flips[id]
      const status  = f.isResolved ? (f.won ? "WON" : "LOST") : "pending reveal"
      const result  = f.isResolved ? (f.result ? "Heads" : "Tails") : "—"
      const choice  = f.playerChoice ? "Heads" : "Tails"

      const outcomeClass = f.isResolved
        ? (f.won ? "flip-outcome" : "flip-outcome lose")
        : "flip-outcome"
      const row = el(
        "div",
        { class: "flip-row" },
        el("span", {}, `#${id}`),
        el("span", {}, `Choice: ${choice}`),
        el("span", {}, `Result: ${result}`),
        el("span", { class: outcomeClass }, status)
      )
      historyDiv.appendChild(row)
    }
  } catch {
    // Script fails silently if contract not yet deployed.
  }
}

function setResult(msg: string, outcome?: "win" | "lose"): void {
  resultDiv.textContent = msg
  resultDiv.classList.remove("win", "lose")
  if (outcome) resultDiv.classList.add(outcome)
}
