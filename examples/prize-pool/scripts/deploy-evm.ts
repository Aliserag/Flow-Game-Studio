import { ethers } from "hardhat"

/// deploy-evm.ts — Deploy MockToken + PrizePool to Flow EVM (emulator or testnet).
///
/// Run: npx hardhat run scripts/deploy-evm.ts --network flow-emulator
///
/// After deploying, record the addresses and:
/// 1. Transfer ownership of PrizePool to the COA address (from setup_coa.cdc)
/// 2. Update fcl-config.ts with the deployed addresses

async function main() {
  const [deployer] = await ethers.getSigners()
  console.log("Deploying from:", deployer.address)
  console.log(
    "Balance:",
    ethers.formatEther(await ethers.provider.getBalance(deployer.address)),
    "FLOW"
  )

  // ── Step 1: Deploy MockToken ─────────────────────────────────────────────────
  console.log("\n[1/3] Deploying MockToken...")
  const TokenFactory = await ethers.getContractFactory("MockToken")
  const token = await TokenFactory.deploy(
    "Prize Token",
    "PTK",
    ethers.parseEther("1000000") // 1M initial supply to deployer
  )
  await token.waitForDeployment()
  const tokenAddress = await token.getAddress()
  console.log("  MockToken deployed:", tokenAddress)

  // ── Step 2: Deploy PrizePool ─────────────────────────────────────────────────
  console.log("\n[2/3] Deploying PrizePool...")
  const PoolFactory = await ethers.getContractFactory("PrizePool")
  const pool = await PoolFactory.deploy(tokenAddress)
  await pool.waitForDeployment()
  const poolAddress = await pool.getAddress()
  console.log("  PrizePool deployed:", poolAddress)
  console.log("  Owner (deployer):", await pool.owner())

  // ── Step 3: Mint test tokens to deployer for testing ────────────────────────
  console.log("\n[3/3] Minting test tokens...")
  await token.mint(deployer.address, ethers.parseEther("10000"))
  console.log("  Minted 10,000 PTK to deployer")

  // ── Summary ──────────────────────────────────────────────────────────────────
  console.log("\n─────────────────────────────────────────────")
  console.log("Deployment complete!")
  console.log("  Token address: ", tokenAddress)
  console.log("  PrizePool address:", poolAddress)
  console.log("\nNext steps:")
  console.log("  1. Run setup_coa.cdc to get your COA EVM address")
  console.log(
    "  2. Call pool.transferOwnership(<COA_ADDRESS>) to hand control to Cadence"
  )
  console.log("  3. Update client/src/fcl-config.ts with these addresses")
}

main().catch((err) => {
  console.error(err)
  process.exitCode = 1
})
