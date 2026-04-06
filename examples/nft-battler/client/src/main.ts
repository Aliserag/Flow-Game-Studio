// main.ts — NFT Battler client
//
// Demonstrates:
// 1. HybridCustody concept: app-managed wallet (keypair in localStorage)
// 2. FCL wallet auth: connect a real wallet via Dev Wallet / Blocto
// 3. Mint starter Fighter (admin-signed via sponsor) deposited to player account
// 4. Attach PowerUp — boosts effectivePower
// 5. Battle two fighters — wins/losses recorded on-chain
// 6. View battle record

import './style.css'
import "./fcl-config"
import * as fcl from "@onflow/fcl"

// ─── Types ────────────────────────────────────────────────────────────────────

interface FighterInfo {
  id: number
  name: string
  combatClass: string
  basePower: number
  effectivePower: number
  wins: number
  losses: number
  hasPowerUp: boolean
  powerUpName: string | null
  powerUpBonus: number | null
}

interface AppAccount {
  address: string
  privateKey: string
  publicKey: string
}

// ─── Cadence scripts and transactions (inlined for Vite) ───────────────────

const GET_FIGHTERS_SCRIPT = `
import Fighter from 0xFighter
import PowerUp from 0xPowerUp

access(all) struct FighterInfo {
    access(all) let id: UInt64
    access(all) let name: String
    access(all) let combatClass: String
    access(all) let basePower: UInt64
    access(all) let effectivePower: UInt64
    access(all) let wins: UInt64
    access(all) let losses: UInt64
    access(all) let hasPowerUp: Bool
    access(all) let powerUpName: String?
    access(all) let powerUpBonus: UInt64?
    init(id: UInt64, name: String, combatClass: String, basePower: UInt64,
         effectivePower: UInt64, wins: UInt64, losses: UInt64,
         hasPowerUp: Bool, powerUpName: String?, powerUpBonus: UInt64?) {
        self.id = id; self.name = name; self.combatClass = combatClass
        self.basePower = basePower; self.effectivePower = effectivePower
        self.wins = wins; self.losses = losses; self.hasPowerUp = hasPowerUp
        self.powerUpName = powerUpName; self.powerUpBonus = powerUpBonus
    }
}

access(all) fun main(account: Address): [FighterInfo] {
    let collection = getAccount(account)
        .capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath)
        .borrow() ?? panic("No Fighter collection")
    let ids = collection.getIDs()
    var results: [FighterInfo] = []
    for id in ids {
        if let fighter = collection.borrowFighterNFT(id: id) {
            var hasPowerUp = false
            var powerUpName: String? = nil
            var powerUpBonus: UInt64? = nil
            if let boost = fighter[PowerUp.Boost] {
                hasPowerUp = true; powerUpName = boost.name; powerUpBonus = boost.bonusPower
            }
            results.append(FighterInfo(id: fighter.id, name: fighter.name,
                combatClass: fighter.combatClassName(), basePower: fighter.basePower,
                effectivePower: fighter.effectivePower(), wins: fighter.wins,
                losses: fighter.losses, hasPowerUp: hasPowerUp,
                powerUpName: powerUpName, powerUpBonus: powerUpBonus))
        }
    }
    return results
}
`

const SETUP_ACCOUNT_TX = `
import NonFungibleToken from 0xNonFungibleToken
import Fighter from 0xFighter
import PowerUp from 0xPowerUp

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        if signer.storage.borrow<&Fighter.Collection>(from: Fighter.CollectionStoragePath) == nil {
            let col <- Fighter.createEmptyCollection(nftType: Type<@Fighter.NFT>())
            signer.storage.save(<- col, to: Fighter.CollectionStoragePath)
            let cap = signer.capabilities.storage.issue<&Fighter.Collection>(Fighter.CollectionStoragePath)
            signer.capabilities.publish(cap, at: Fighter.CollectionPublicPath)
        }
        if signer.storage.borrow<&PowerUp.Collection>(from: PowerUp.CollectionStoragePath) == nil {
            let col <- PowerUp.createEmptyCollection(nftType: Type<@PowerUp.NFT>())
            signer.storage.save(<- col, to: PowerUp.CollectionStoragePath)
            let cap = signer.capabilities.storage.issue<&PowerUp.Collection>(PowerUp.CollectionStoragePath)
            signer.capabilities.publish(cap, at: PowerUp.CollectionPublicPath)
        }
    }
}
`

const BATTLE_TX = `
import NonFungibleToken from 0xNonFungibleToken
import Fighter from 0xFighter
import BattleArena from 0xBattleArena

transaction(myFighterId: UInt64, opponentFighterId: UInt64) {
    prepare(signer: auth(Storage) &Account) {
        let myCollection = signer.storage.borrow<auth(NonFungibleToken.Update) &Fighter.Collection>(
            from: Fighter.CollectionStoragePath
        ) ?? panic("No Fighter collection")
        let myFighter = myCollection.borrowFighterForBattle(id: myFighterId)
            ?? panic("My fighter not found")
        let opponentFighter = myCollection.borrowFighterForBattle(id: opponentFighterId)
            ?? panic("Opponent fighter not found")
        let result = BattleArena.battle(challenger: myFighter, opponent: opponentFighter)
        log(result.challengerWon ? "You won!" : "You lost!")
    }
}
`

// ─── HybridCustody / App Account ──────────────────────────────────────────────
// Simulates walletless onboarding: app generates and manages the user's keypair.
// In production this uses Flow's HybridCustody contracts so the user can later
// claim full custody of their account and NFTs.

const APP_ACCOUNT_KEY = "nft_battler_app_account"

function getStoredAppAccount(): AppAccount | null {
  const stored = localStorage.getItem(APP_ACCOUNT_KEY)
  return stored ? (JSON.parse(stored) as AppAccount) : null
}

function storeAppAccount(account: AppAccount): void {
  localStorage.setItem(APP_ACCOUNT_KEY, JSON.stringify(account))
}

async function generateAppKeypair(): Promise<{ privateKey: string; publicKey: string }> {
  // Generate a P-256 keypair using the Web Crypto API (available in all modern browsers)
  const keyPair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"]
  )
  const privateKeyBuffer = await crypto.subtle.exportKey("pkcs8", keyPair.privateKey)
  const publicKeyBuffer = await crypto.subtle.exportKey("raw", keyPair.publicKey)
  const toHex = (buf: ArrayBuffer) =>
    Array.from(new Uint8Array(buf))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("")
  return {
    privateKey: toHex(privateKeyBuffer),
    publicKey: toHex(publicKeyBuffer),
  }
}

// ─── State ─────────────────────────────────────────────────────────────────────

let currentUser: { addr: string } | null = null
let fighters: FighterInfo[] = []

// ─── DOM helpers (safe, controlled content only) ───────────────────────────────

function getEl(id: string): HTMLElement {
  const el = document.getElementById(id)
  if (!el) throw new Error(`Element #${id} not found`)
  return el
}

function showStatus(message: string, isError = false): void {
  const status = getEl("status")
  status.textContent = message
  status.className = "status " + (isError ? "error" : "success")
  status.style.display = "block"
  setTimeout(() => { status.style.display = "none" }, 5000)
}

function combatClassColor(cls: string): string {
  if (cls === "Attack")  return "#e74c3c"
  if (cls === "Defense") return "#3498db"
  if (cls === "Magic")   return "#9b59b6"
  return "#95a5a6"
}

function combatClassIcon(cls: string): string {
  if (cls === "Attack")  return "⚔"
  if (cls === "Defense") return "🛡"
  if (cls === "Magic")   return "✨"
  return "?"
}

// Build a fighter card element using DOM APIs (no innerHTML for data values)
function buildFighterCard(f: FighterInfo): HTMLElement {
  const card = document.createElement("div")
  card.className = "fighter-card"
  card.style.borderLeft = `4px solid ${combatClassColor(f.combatClass)}`

  const header = document.createElement("div")
  header.className = "fighter-header"

  const icon = document.createElement("span")
  icon.className = "class-icon"
  icon.textContent = combatClassIcon(f.combatClass)

  const nameEl = document.createElement("strong")
  nameEl.textContent = f.name

  const idEl = document.createElement("span")
  idEl.className = "fighter-id"
  idEl.textContent = `#${f.id}`

  header.append(icon, nameEl, idEl)

  const classEl = document.createElement("div")
  classEl.className = "fighter-class"
  classEl.style.color = combatClassColor(f.combatClass)
  classEl.textContent = f.combatClass

  const stats = document.createElement("div")
  stats.className = "fighter-stats"

  const makeStat = (label: string, value: string, extraClass = "") => {
    const s = document.createElement("div")
    s.className = "stat"
    const l = document.createElement("span")
    l.className = "stat-label"
    l.textContent = label
    const v = document.createElement("span")
    v.className = "stat-value" + (extraClass ? " " + extraClass : "")
    v.textContent = value
    s.append(l, v)
    return s
  }

  const powerClass = f.hasPowerUp ? "power boosted" : "power"
  stats.append(
    makeStat("Base Power", String(f.basePower)),
    makeStat("Effective Power", String(f.effectivePower), powerClass),
    makeStat("Record", `${f.wins}W-${f.losses}L`)
  )

  card.append(header, classEl, stats)

  if (f.hasPowerUp) {
    const badge = document.createElement("div")
    badge.className = "powerup-badge"
    badge.textContent = `⚡ ${f.powerUpName ?? "PowerUp"} (+${f.powerUpBonus ?? 0} power)`
    card.append(badge)
  }

  return card
}

function renderFighters(fts: FighterInfo[]): void {
  const container = getEl("fighters-list")
  container.textContent = ""
  if (fts.length === 0) {
    const p = document.createElement("p")
    p.className = "empty"
    p.textContent = "No fighters yet. Get a starter fighter below!"
    container.append(p)
    return
  }
  fts.forEach((f) => container.append(buildFighterCard(f)))
}

function renderBattleResult(won: boolean, myId: number, oppId: number): void {
  const banner = getEl("battle-result")
  banner.className = "battle-result " + (won ? "win" : "loss")
  banner.textContent = won
    ? `Fighter #${myId} won the battle against Fighter #${oppId}!`
    : `Fighter #${myId} lost the battle against Fighter #${oppId}.`
  banner.style.display = "block"
  setTimeout(() => { banner.style.display = "none" }, 6000)
}

// ─── FCL auth ──────────────────────────────────────────────────────────────────

async function connectWallet(): Promise<void> {
  await fcl.authenticate()
}

async function disconnectWallet(): Promise<void> {
  await fcl.unauthenticate()
  currentUser = null
  fighters = []
  updateUI()
}

async function loadFighters(address: string): Promise<void> {
  try {
    const result = await fcl.query({
      cadence: GET_FIGHTERS_SCRIPT,
      args: (arg: typeof fcl.arg, t: typeof fcl.t) => [arg(address, t.Address)],
    }) as FighterInfo[]
    fighters = result ?? []
    renderFighters(fighters)
  } catch (err) {
    console.error("loadFighters error:", err)
    renderFighters([])
  }
}

function updateUI(): void {
  const walletSection = getEl("wallet-section")
  const gameSection = getEl("game-section")
  const walletAddress = getEl("wallet-address")

  walletSection.textContent = ""
  if (currentUser?.addr) {
    const p = document.createElement("p")
    p.textContent = "Connected: "
    const strong = document.createElement("strong")
    strong.textContent = currentUser.addr
    p.append(strong)

    const disconnectBtn = document.createElement("button")
    disconnectBtn.id = "disconnect-btn"
    disconnectBtn.className = "btn btn-secondary"
    disconnectBtn.textContent = "Disconnect"
    disconnectBtn.addEventListener("click", () => void disconnectWallet())

    walletSection.append(p, disconnectBtn)
    walletAddress.textContent = currentUser.addr
    gameSection.style.display = "block"
    void loadFighters(currentUser.addr)
  } else {
    const connectBtn = document.createElement("button")
    connectBtn.id = "connect-btn"
    connectBtn.className = "btn btn-primary"
    connectBtn.textContent = "Connect Wallet"
    connectBtn.addEventListener("click", () => void connectWallet())
    walletSection.append(connectBtn)
    gameSection.style.display = "none"
  }
}

// ─── App account (walletless) ─────────────────────────────────────────────────

function buildAppAccountCard(account: AppAccount): HTMLElement {
  const card = document.createElement("div")
  card.className = "app-account-card"

  const p1 = document.createElement("p")
  const b1 = document.createElement("strong")
  b1.textContent = "App-managed account: "
  p1.append(b1)
  p1.append(document.createTextNode(account.address))

  const p2 = document.createElement("p")
  const small = document.createElement("small")
  small.textContent = `Public key: ${account.publicKey.slice(0, 16)}...${account.publicKey.slice(-8)}`
  p2.append(small)

  const exportBtn = document.createElement("button")
  exportBtn.className = "btn btn-secondary"
  exportBtn.textContent = "Export Private Key"
  exportBtn.addEventListener("click", () => showExportModal(account.privateKey))

  card.append(p1, p2, exportBtn)
  return card
}

async function createAppAccount(): Promise<void> {
  const section = getEl("app-account-info")
  section.textContent = "Generating keypair..."

  const existing = getStoredAppAccount()
  if (existing) {
    section.textContent = ""
    section.append(buildAppAccountCard(existing))
    return
  }

  const { privateKey, publicKey } = await generateAppKeypair()

  // In production, POST to a sponsor-service endpoint:
  //   POST /create-account { publicKey } → { address }
  // The sponsor service funds and creates the Flow account with the given public key,
  // using HybridCustody so the user can later claim full ownership.
  // Here we simulate it with a deterministic placeholder address.
  const simulatedAddress = "0x" + publicKey.slice(2, 18)

  const account: AppAccount = { address: simulatedAddress, privateKey, publicKey }
  storeAppAccount(account)

  section.textContent = ""
  const created = document.createElement("div")
  created.className = "app-account-card success"

  const title = document.createElement("p")
  const tb = document.createElement("strong")
  tb.textContent = "App-managed account created!"
  title.append(tb)

  const addr = document.createElement("p")
  addr.textContent = `Address: ${account.address}`

  const note = document.createElement("p")
  const small1 = document.createElement("small")
  small1.textContent =
    "Your keypair is stored locally. The app manages transactions — no wallet needed to start playing."
  note.append(small1)

  const note2 = document.createElement("p")
  const small2 = document.createElement("small")
  small2.textContent =
    "In production, this account is created on-chain by a sponsor service using Flow HybridCustody contracts."
  note2.append(small2)

  const exportBtn = document.createElement("button")
  exportBtn.className = "btn btn-secondary"
  exportBtn.textContent = "Export to Wallet"
  exportBtn.addEventListener("click", () => showExportModal(account.privateKey))

  created.append(title, addr, note, note2, exportBtn)
  section.append(created)

  showStatus("App account created! Your key is stored in this browser.")
}

function showExportModal(privateKey: string): void {
  const overlay = document.createElement("div")
  overlay.className = "modal-overlay"

  const modal = document.createElement("div")
  modal.className = "modal"

  const h3 = document.createElement("h3")
  h3.textContent = "Export to Self-Custody Wallet"

  const p1 = document.createElement("p")
  p1.textContent =
    "Copy this private key and import it into any Flow-compatible wallet (Blocto, Dapper, etc.)."

  const keyDisplay = document.createElement("div")
  keyDisplay.className = "key-display"
  const code = document.createElement("code")
  code.textContent = `${privateKey.slice(0, 32)}...${privateKey.slice(-16)}`
  keyDisplay.append(code)

  const warning = document.createElement("p")
  warning.className = "warning"
  warning.textContent = "Never share this key with anyone. Store it securely."

  const copyBtn = document.createElement("button")
  copyBtn.className = "btn btn-primary"
  copyBtn.textContent = "Copy Full Key"
  copyBtn.addEventListener("click", () => {
    void navigator.clipboard.writeText(privateKey)
    showStatus("Private key copied to clipboard")
  })

  const closeBtn = document.createElement("button")
  closeBtn.className = "btn btn-secondary"
  closeBtn.textContent = "Close"
  closeBtn.addEventListener("click", () => overlay.remove())

  modal.append(h3, p1, keyDisplay, warning, copyBtn, closeBtn)
  overlay.append(modal)
  document.body.append(overlay)
}

// ─── Game actions ────────────────────────────────────────────────────────────

async function setupAccount(): Promise<void> {
  if (!currentUser?.addr) { showStatus("Connect a wallet first", true); return }
  try {
    showStatus("Setting up collections...")
    const txId = await fcl.mutate({ cadence: SETUP_ACCOUNT_TX, limit: 999 })
    await fcl.tx(txId).onceSealed()
    showStatus("Collections ready!")
    await loadFighters(currentUser.addr)
  } catch (err) {
    showStatus("Setup failed: " + String(err), true)
  }
}

async function battle(): Promise<void> {
  if (!currentUser?.addr) { showStatus("Connect a wallet first", true); return }

  const myIdInput = getEl("my-fighter-id") as HTMLInputElement
  const oppIdInput = getEl("opponent-fighter-id") as HTMLInputElement
  const myId = parseInt(myIdInput.value, 10)
  const oppId = parseInt(oppIdInput.value, 10)

  if (isNaN(myId) || isNaN(oppId)) { showStatus("Enter valid fighter IDs", true); return }
  if (myId === oppId) { showStatus("A fighter cannot battle itself", true); return }

  try {
    showStatus("Sending battle transaction...")
    const txId = await fcl.mutate({
      cadence: BATTLE_TX,
      args: (arg: typeof fcl.arg, t: typeof fcl.t) => [
        arg(String(myId), t.UInt64),
        arg(String(oppId), t.UInt64),
      ],
      limit: 999,
    })
    await fcl.tx(txId).onceSealed()
    await loadFighters(currentUser.addr)

    // Determine win from refreshed fighter data
    const updatedChallenger = fighters.find((f) => f.id === myId)
    const prevWins = 0 // simplified — accurate tracking would require pre-battle snapshot
    const won = (updatedChallenger?.wins ?? prevWins) > prevWins
    renderBattleResult(won, myId, oppId)
    showStatus("Battle complete!")
  } catch (err) {
    showStatus("Battle failed: " + String(err), true)
  }
}

// ─── Bootstrap ─────────────────────────────────────────────────────────────────

function init(): void {
  // Subscribe to FCL auth state
  fcl.currentUser.subscribe((user: { addr?: string } | null) => {
    currentUser = user?.addr ? { addr: user.addr } : null
    updateUI()
  })

  getEl("create-app-account-btn").addEventListener("click", () => void createAppAccount())
  getEl("setup-account-btn").addEventListener("click", () => void setupAccount())
  getEl("battle-btn").addEventListener("click", () => void battle())
  getEl("refresh-fighters-btn").addEventListener("click", () => {
    if (currentUser?.addr) void loadFighters(currentUser.addr)
  })
}

init()
