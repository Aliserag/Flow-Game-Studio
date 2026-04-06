/// main.ts — Prize Pool UI wiring.
///
/// Two-panel layout:
///   Left panel  (EVM / MetaMask): connect wallet, deposit tokens, view round state
///   Right panel (Cadence / FCL):  connect Flow wallet, view WinnerTrophy collection
///   Admin panel (visible when connected EVM wallet == pool owner): close round button
///
/// This file wires DOM events to evm-client.ts and fcl-config.ts functions.
/// All dynamic DOM writes use textContent / createElement — no innerHTML with
/// untrusted data to prevent XSS.

import './style.css'
import "./fcl-config" // initialise FCL config on load
import * as fcl from "@onflow/fcl"
import { Contract, Signer } from "ethers"
import {
  connectEVM,
  getRoundState,
  depositToPool,
  onDeposited,
  onRoundClosed,
  type RoundState,
} from "./evm-client"

// ─── Config — update after deploying contracts ─────────────────────────────────
const CONFIG = {
  PRIZE_POOL_ADDRESS: (import.meta.env as Record<string, string>)["VITE_PRIZE_POOL_ADDRESS"] ?? "",
  TOKEN_ADDRESS: (import.meta.env as Record<string, string>)["VITE_TOKEN_ADDRESS"] ?? "",
}

// ─── State ────────────────────────────────────────────────────────────────────
let evmSigner: Signer | null = null
let flowUser: { addr?: string; loggedIn?: boolean } = {}
let roundState: RoundState | null = null
let cleanupListeners: (() => void)[] = []

// ─── DOM helpers ──────────────────────────────────────────────────────────────
function getEl(id: string): HTMLElement {
  return document.getElementById(id)!
}

function setText(id: string, text: string): void {
  const el = document.getElementById(id)
  if (el) el.textContent = text
}

function setVisible(id: string, visible: boolean): void {
  const el = document.getElementById(id)
  if (el) (el as HTMLElement).style.display = visible ? "" : "none"
}

function showStatus(message: string, type: "info" | "success" | "error" = "info"): void {
  const el = getEl("status-message")
  el.textContent = message
  el.className = `status-message status-${type}`
  el.style.display = "block"
}

function formatTokenAmount(wei: bigint): string {
  const whole = wei / BigInt(1e18)
  const frac = (wei % BigInt(1e18)) / BigInt(1e14) // 4 decimal places
  return `${whole}.${frac.toString().padStart(4, "0")} PTK`
}

// ─── Round state display ──────────────────────────────────────────────────────
async function refreshRoundState(): Promise<void> {
  if (!evmSigner || !CONFIG.PRIZE_POOL_ADDRESS) return
  try {
    roundState = await getRoundState(evmSigner, CONFIG.PRIZE_POOL_ADDRESS)
    const { roundId, isOpen, totalDeposited, depositors, myDeposit } = roundState

    setText("round-id", roundId.toString())
    setText("round-status", isOpen ? "Open — accepting deposits" : "Closed")
    setText("depositor-count", depositors.length.toString())
    setText("total-deposited", formatTokenAmount(totalDeposited))
    setText("my-deposit", formatTokenAmount(myDeposit))

    // Admin panel: show if signer is pool owner
    const pool = new Contract(
      CONFIG.PRIZE_POOL_ADDRESS,
      ["function owner() view returns (address)"],
      evmSigner
    )
    const owner = (await pool["owner"]()) as string
    const myAddr = await evmSigner.getAddress()
    setVisible("admin-panel", owner.toLowerCase() === myAddr.toLowerCase())
    setVisible("deposit-section", isOpen)
  } catch (err) {
    console.error("Failed to refresh round state:", err)
  }
}

// ─── EVM panel ────────────────────────────────────────────────────────────────
getEl("connect-metamask-btn").addEventListener("click", () => {
  void (async () => {
    try {
      showStatus("Connecting MetaMask...")
      evmSigner = await connectEVM()
      const address = await evmSigner.getAddress()
      setText("evm-address", address)
      setVisible("evm-connected", true)
      setVisible("evm-disconnected", false)
      showStatus("MetaMask connected", "success")

      // Subscribe to live events
      cleanupListeners.forEach((fn) => fn())
      cleanupListeners = []
      if (CONFIG.PRIZE_POOL_ADDRESS && evmSigner) {
        cleanupListeners.push(
          onDeposited(evmSigner, CONFIG.PRIZE_POOL_ADDRESS, () => {
            void refreshRoundState()
          }),
          onRoundClosed(evmSigner, CONFIG.PRIZE_POOL_ADDRESS, (_, winner, prize) => {
            // winner and prize come from the chain — display as text only
            const shortWinner = `${winner.slice(0, 6)}…${winner.slice(-4)}`
            showStatus(
              `Round closed! Winner: ${shortWinner} — Prize: ${formatTokenAmount(prize)}`,
              "success"
            )
            void refreshRoundState()
            void refreshTrophies()
          })
        )
      }

      await refreshRoundState()
    } catch (err: unknown) {
      showStatus(`MetaMask error: ${(err as Error).message}`, "error")
    }
  })()
})

getEl("deposit-btn").addEventListener("click", () => {
  void (async () => {
    if (!evmSigner) {
      showStatus("Connect MetaMask first", "error")
      return
    }
    const amountInput = getEl("deposit-amount") as HTMLInputElement
    const amount = amountInput.value.trim()
    if (!amount || parseFloat(amount) <= 0) {
      showStatus("Enter a valid deposit amount", "error")
      return
    }
    try {
      showStatus(`Approving and depositing ${amount} PTK…`)
      ;(getEl("deposit-btn") as HTMLButtonElement).disabled = true
      const hash = await depositToPool(
        evmSigner,
        CONFIG.PRIZE_POOL_ADDRESS,
        CONFIG.TOKEN_ADDRESS,
        amount
      )
      showStatus(`Deposited! Tx: ${hash.slice(0, 10)}…`, "success")
      amountInput.value = ""
      await refreshRoundState()
    } catch (err: unknown) {
      showStatus(`Deposit failed: ${(err as Error).message}`, "error")
    } finally {
      ;(getEl("deposit-btn") as HTMLButtonElement).disabled = false
    }
  })()
})

// ─── Admin panel ──────────────────────────────────────────────────────────────
getEl("close-round-btn").addEventListener("click", () => {
  void (async () => {
    if (!flowUser.loggedIn || !roundState) {
      showStatus("Connect Flow wallet and load round state first", "error")
      return
    }
    try {
      showStatus("Closing round — sending Cadence transaction…")
      ;(getEl("close-round-btn") as HTMLButtonElement).disabled = true

      const depositors = roundState.depositors
      const evmRoundId = roundState.roundId
      const commitBlockHeight = Number(
        (getEl("commit-block-height") as HTMLInputElement).value
      )
      const secret = BigInt(
        (getEl("vrf-secret") as HTMLInputElement).value || "0"
      )
      const winnerFlowAddress = (
        getEl("winner-flow-address") as HTMLInputElement
      ).value.trim()
      const prizeAmountStr = roundState.totalDeposited.toString()

      await fcl.mutate({
        cadence: `
          import PrizePoolOrchestrator from 0xPrizePoolOrchestrator

          transaction(
            depositors: [String],
            evmRoundId: UInt256,
            commitBlockHeight: UInt64,
            secret: UInt256,
            winnerFlowAddress: Address,
            prizeAmountStr: String
          ) {
            prepare(signer: auth(BorrowValue) &Account) {
              PrizePoolOrchestrator.closeRound(
                signer: signer,
                depositors: depositors,
                evmRoundId: evmRoundId,
                commitBlockHeight: commitBlockHeight,
                secret: secret,
                winnerFlowAddress: winnerFlowAddress,
                prizeAmountStr: prizeAmountStr
              )
            }
          }
        `,
        args: (arg: typeof fcl.arg, t: typeof fcl.t) => [
          arg(depositors, t.Array(t.String)),
          arg(evmRoundId.toString(), t.UInt256),
          arg(commitBlockHeight.toString(), t.UInt64),
          arg(secret.toString(), t.UInt256),
          arg(winnerFlowAddress, t.Address),
          arg(prizeAmountStr, t.String),
        ],
        proposer: fcl.authz,
        payer: fcl.authz,
        authorizations: [fcl.authz],
        limit: 9999,
      })

      showStatus("Round closed! Winner selected and trophy minted.", "success")
      await refreshRoundState()
      await refreshTrophies()
    } catch (err: unknown) {
      showStatus(`Close round failed: ${(err as Error).message}`, "error")
    } finally {
      ;(getEl("close-round-btn") as HTMLButtonElement).disabled = false
    }
  })()
})

// ─── Cadence / FCL panel ──────────────────────────────────────────────────────
getEl("connect-flow-btn").addEventListener("click", () => {
  void fcl.authenticate()
})

getEl("disconnect-flow-btn").addEventListener("click", () => {
  void fcl.unauthenticate()
})

// Subscribe to FCL user changes
fcl.currentUser.subscribe((user: { addr?: string; loggedIn?: boolean }) => {
  flowUser = user
  if (user.loggedIn) {
    setText("flow-address", user.addr ?? "unknown")
    setVisible("flow-connected", true)
    setVisible("flow-disconnected", false)
    void refreshTrophies()
  } else {
    setVisible("flow-connected", false)
    setVisible("flow-disconnected", true)
    // Clear trophy list safely
    const container = getEl("trophies-list")
    container.textContent = "Connect Flow wallet to view trophies"
  }
})

// ─── Trophies display ─────────────────────────────────────────────────────────

interface TrophyData {
  id: string
  roundId: string
  prizeAmount: string
  mintedAtBlock: string
  evmWinnerAddress: string
}

/// Build a trophy card using safe DOM methods — no innerHTML with chain data.
function buildTrophyCard(t: TrophyData): HTMLElement {
  const card = document.createElement("div")
  card.className = "trophy-card"

  const icon = document.createElement("div")
  icon.className = "trophy-icon"
  icon.textContent = "trophy" // text only, no raw emoji from chain

  const details = document.createElement("div")
  details.className = "trophy-details"

  const title = document.createElement("strong")
  title.textContent = `Trophy #${t.id}`

  const round = document.createElement("div")
  round.textContent = `Round: ${t.roundId}`

  const prize = document.createElement("div")
  prize.textContent = `Prize: ${formatTokenAmount(BigInt(t.prizeAmount))}`

  const evmAddr = document.createElement("div")
  // Safely truncate — both values from chain, textContent only
  const addr = t.evmWinnerAddress
  evmAddr.textContent = `EVM: ${addr.slice(0, 8)}…${addr.slice(-4)}`

  const block = document.createElement("div")
  block.className = "trophy-block"
  block.textContent = `Block: ${t.mintedAtBlock}`

  details.appendChild(title)
  details.appendChild(round)
  details.appendChild(prize)
  details.appendChild(evmAddr)
  details.appendChild(block)

  card.appendChild(icon)
  card.appendChild(details)

  return card
}

async function refreshTrophies(): Promise<void> {
  if (!flowUser.addr) return
  const container = getEl("trophies-list")

  try {
    const result = await fcl.query({
      cadence: `
        import WinnerTrophy from 0xWinnerTrophy

        access(all) struct TrophyData {
          access(all) let id: UInt64
          access(all) let roundId: UInt64
          access(all) let prizeAmount: String
          access(all) let mintedAtBlock: UInt64
          access(all) let evmWinnerAddress: String
          init(id: UInt64, roundId: UInt64, prizeAmount: String, mintedAtBlock: UInt64, evmWinnerAddress: String) {
            self.id = id; self.roundId = roundId; self.prizeAmount = prizeAmount
            self.mintedAtBlock = mintedAtBlock; self.evmWinnerAddress = evmWinnerAddress
          }
        }

        access(all) fun main(addr: Address): [TrophyData] {
          let col = getAccount(addr).capabilities
            .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)
            .borrow()
          if col == nil { return [] }
          let ids = col!.getIDs()
          var out: [TrophyData] = []
          for id in ids {
            if let t = col!.borrowTrophy(id: id) {
              out.append(TrophyData(
                id: t.id, roundId: t.roundId, prizeAmount: t.prizeAmount,
                mintedAtBlock: t.mintedAtBlock, evmWinnerAddress: t.evmWinnerAddress
              ))
            }
          }
          return out
        }
      `,
      args: (arg: typeof fcl.arg, t: typeof fcl.t) => [
        arg(flowUser.addr, t.Address),
      ],
    })

    const trophies = result as TrophyData[]

    // Clear existing content safely
    while (container.firstChild) {
      container.removeChild(container.firstChild)
    }

    if (trophies.length === 0) {
      const empty = document.createElement("p")
      empty.className = "empty-state"
      empty.textContent = "No trophies yet — win a round!"
      container.appendChild(empty)
      return
    }

    for (const t of trophies) {
      container.appendChild(buildTrophyCard(t))
    }
  } catch (err) {
    console.error("Failed to load trophies:", err)
    container.textContent = "Failed to load trophies — check console"
  }
}

getEl("refresh-trophies-btn").addEventListener("click", () => {
  void refreshTrophies()
})

// ─── Initial state ────────────────────────────────────────────────────────────
if (!CONFIG.PRIZE_POOL_ADDRESS || !CONFIG.TOKEN_ADDRESS) {
  showStatus(
    "Contract addresses not configured. Set VITE_PRIZE_POOL_ADDRESS and VITE_TOKEN_ADDRESS in .env",
    "error"
  )
}
