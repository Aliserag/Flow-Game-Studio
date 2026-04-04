/// evm-client.ts — ethers.js interactions with the PrizePool Solidity contract.
/// Players use MetaMask (or any EIP-1193 wallet) to deposit ERC-20 tokens.

import { ethers, BrowserProvider, Contract, Signer } from "ethers"

// ─── ABI ─────────────────────────────────────────────────────────────────────

const PRIZE_POOL_ABI = [
  "function deposit(uint256 amount) external",
  "function closeRound(address winner) external",
  "function openNewRound() external",
  "function getDepositors(uint256 roundId) view returns (address[])",
  "function getDeposit(uint256 roundId, address player) view returns (uint256)",
  "function totalDeposited(uint256) view returns (uint256)",
  "function roundId() view returns (uint256)",
  "function isOpen() view returns (bool)",
  "function owner() view returns (address)",
  "event Deposited(uint256 indexed roundId, address indexed player, uint256 amount)",
  "event RoundClosed(uint256 indexed roundId, address indexed winner, uint256 prize)",
  "event RoundOpened(uint256 indexed roundId)",
] as const

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
] as const

// ─── Types ────────────────────────────────────────────────────────────────────

export interface RoundState {
  roundId: bigint
  isOpen: boolean
  totalDeposited: bigint
  depositors: string[]
  myDeposit: bigint
}

export interface TokenInfo {
  symbol: string
  decimals: number
  balance: bigint
  allowance: bigint
}

// ─── Connection ───────────────────────────────────────────────────────────────

/// Connect MetaMask and return a signer.
export async function connectEVM(): Promise<Signer> {
  if (!window.ethereum) {
    throw new Error("MetaMask not found — please install MetaMask")
  }
  await window.ethereum.request({ method: "eth_requestAccounts" })
  const provider = new BrowserProvider(window.ethereum)

  // Prompt to switch to Flow EVM emulator (chainId 1337) if needed
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: "0x539" }], // 1337 hex
    })
  } catch (_switchErr: unknown) {
    // If chain not added, add it
    const switchErr = _switchErr as { code: number }
    if (switchErr.code === 4902) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [
          {
            chainId: "0x539",
            chainName: "Flow EVM Emulator",
            rpcUrls: ["http://localhost:8545"],
            nativeCurrency: { name: "FLOW", symbol: "FLOW", decimals: 18 },
          },
        ],
      })
    }
  }

  return provider.getSigner()
}

// ─── Token info ───────────────────────────────────────────────────────────────

/// Fetch ERC-20 token info for display.
export async function getTokenInfo(
  signer: Signer,
  tokenAddress: string,
  prizePoolAddress: string
): Promise<TokenInfo> {
  const token = new Contract(tokenAddress, ERC20_ABI, signer)
  const address = await signer.getAddress()
  const [symbol, decimals, balance, allowance] = await Promise.all([
    token.symbol() as Promise<string>,
    token.decimals() as Promise<number>,
    token.balanceOf(address) as Promise<bigint>,
    token.allowance(address, prizePoolAddress) as Promise<bigint>,
  ])
  return { symbol, decimals, balance, allowance }
}

// ─── Round state ──────────────────────────────────────────────────────────────

/// Fetch current round state from the PrizePool contract.
export async function getRoundState(
  signer: Signer,
  prizePoolAddress: string
): Promise<RoundState> {
  const pool = new Contract(prizePoolAddress, PRIZE_POOL_ABI, signer)
  const address = await signer.getAddress()

  const [roundId, isOpen] = await Promise.all([
    pool.roundId() as Promise<bigint>,
    pool.isOpen() as Promise<boolean>,
  ])

  const [totalDeposited, depositors, myDeposit] = await Promise.all([
    pool.totalDeposited(roundId) as Promise<bigint>,
    pool.getDepositors(roundId) as Promise<string[]>,
    pool.getDeposit(roundId, address) as Promise<bigint>,
  ])

  return { roundId, isOpen, totalDeposited, depositors, myDeposit }
}

// ─── Deposit ──────────────────────────────────────────────────────────────────

/// Approve token spend (if needed) then deposit into the prize pool.
/// @param amount — human-readable token amount (e.g. "100" for 100 tokens)
export async function depositToPool(
  signer: Signer,
  prizePoolAddress: string,
  tokenAddress: string,
  amount: string
): Promise<string> {
  const pool = new Contract(prizePoolAddress, PRIZE_POOL_ABI, signer)
  const token = new Contract(tokenAddress, ERC20_ABI, signer)
  const address = await signer.getAddress()

  const decimals = (await token.decimals()) as number
  const amountWei = ethers.parseUnits(amount, decimals)

  // Step 1: Approve if current allowance is insufficient
  const currentAllowance = (await token.allowance(
    address,
    prizePoolAddress
  )) as bigint
  if (currentAllowance < amountWei) {
    const approveTx = await token.approve(prizePoolAddress, amountWei)
    await approveTx.wait()
  }

  // Step 2: Deposit
  const depositTx = await pool.deposit(amountWei)
  const receipt = await depositTx.wait()
  return receipt.hash as string
}

// ─── Listen for events ────────────────────────────────────────────────────────

/// Subscribe to Deposited events for the current round.
export function onDeposited(
  signer: Signer,
  prizePoolAddress: string,
  callback: (roundId: bigint, player: string, amount: bigint) => void
): () => void {
  const pool = new Contract(prizePoolAddress, PRIZE_POOL_ABI, signer)
  const handler = (
    roundId: bigint,
    player: string,
    amount: bigint
  ) => callback(roundId, player, amount)
  pool.on("Deposited", handler)
  return () => { pool.off("Deposited", handler) }
}

/// Subscribe to RoundClosed events.
export function onRoundClosed(
  signer: Signer,
  prizePoolAddress: string,
  callback: (roundId: bigint, winner: string, prize: bigint) => void
): () => void {
  const pool = new Contract(prizePoolAddress, PRIZE_POOL_ABI, signer)
  const handler = (roundId: bigint, winner: string, prize: bigint) =>
    callback(roundId, winner, prize)
  pool.on("RoundClosed", handler)
  return () => { pool.off("RoundClosed", handler) }
}

// ─── Window type augment ──────────────────────────────────────────────────────

declare global {
  interface Window {
    ethereum?: {
      request: (args: { method: string; params?: unknown[] }) => Promise<unknown>
    }
  }
}
