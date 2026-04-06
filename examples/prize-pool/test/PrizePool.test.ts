import { expect } from "chai"
import { ethers } from "hardhat"
import { MockToken, PrizePool } from "../typechain-types"
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers"

describe("PrizePool", () => {
  let token: MockToken
  let pool: PrizePool
  let owner: HardhatEthersSigner
  let player1: HardhatEthersSigner
  let player2: HardhatEthersSigner
  let player3: HardhatEthersSigner

  // Deploy fresh contracts before each test
  beforeEach(async () => {
    ;[owner, player1, player2, player3] = await ethers.getSigners()

    // Deploy MockToken with 1,000,000 initial supply (to owner)
    const TokenFactory = await ethers.getContractFactory("MockToken")
    token = (await TokenFactory.deploy(
      "Prize Token",
      "PTK",
      ethers.parseEther("1000000")
    )) as MockToken
    await token.waitForDeployment()

    // Deploy PrizePool with the token address
    const PoolFactory = await ethers.getContractFactory("PrizePool")
    pool = (await PoolFactory.deploy(await token.getAddress())) as PrizePool
    await pool.waitForDeployment()

    // Fund players with tokens: 1000 PTK each
    await token.mint(player1.address, ethers.parseEther("1000"))
    await token.mint(player2.address, ethers.parseEther("1000"))
    await token.mint(player3.address, ethers.parseEther("1000"))
  })

  // ─── Test 1: Deposit tracking ────────────────────────────────────────────────
  it("allows deposit and tracks depositors", async () => {
    // Arrange: approve pool to spend tokens
    const depositAmount = ethers.parseEther("100")
    await token.connect(player1).approve(await pool.getAddress(), depositAmount)

    // Act: player1 deposits 100 PTK
    await expect(pool.connect(player1).deposit(depositAmount))
      .to.emit(pool, "Deposited")
      .withArgs(0n, player1.address, depositAmount)

    // Assert: state updated correctly
    expect(await pool.totalDeposited(0n)).to.equal(depositAmount)
    expect(await pool.getDeposit(0n, player1.address)).to.equal(depositAmount)

    const depositors = await pool.getDepositors(0n)
    expect(depositors.length).to.equal(1)
    expect(depositors[0]).to.equal(player1.address)
  })

  it("accumulates multiple deposits from multiple players", async () => {
    // Arrange
    const amount1 = ethers.parseEther("50")
    const amount2 = ethers.parseEther("150")
    await token.connect(player1).approve(await pool.getAddress(), amount1)
    await token.connect(player2).approve(await pool.getAddress(), amount2)

    // Act
    await pool.connect(player1).deposit(amount1)
    await pool.connect(player2).deposit(amount2)

    // Assert
    expect(await pool.totalDeposited(0n)).to.equal(amount1 + amount2)
    const depositors = await pool.getDepositors(0n)
    expect(depositors.length).to.equal(2)

    // Same player depositing again should NOT add to depositor list
    await token.connect(player1).approve(await pool.getAddress(), amount1)
    await pool.connect(player1).deposit(amount1)
    const depositorsAfter = await pool.getDepositors(0n)
    expect(depositorsAfter.length).to.equal(2)
    expect(await pool.getDeposit(0n, player1.address)).to.equal(amount1 * 2n)
  })

  // ─── Test 2: Owner closes round and releases prize ────────────────────────────
  it("owner can close round and release prize to winner", async () => {
    // Arrange: player1 deposits 200 PTK, player2 deposits 300 PTK
    const deposit1 = ethers.parseEther("200")
    const deposit2 = ethers.parseEther("300")
    await token.connect(player1).approve(await pool.getAddress(), deposit1)
    await token.connect(player2).approve(await pool.getAddress(), deposit2)
    await pool.connect(player1).deposit(deposit1)
    await pool.connect(player2).deposit(deposit2)

    const totalPrize = deposit1 + deposit2
    const poolAddress = await pool.getAddress()

    // Pre-assert: pool holds all tokens
    expect(await token.balanceOf(poolAddress)).to.equal(totalPrize)

    const winnerBalanceBefore = await token.balanceOf(player1.address)

    // Act: owner (COA in production) closes round with player1 as winner
    await expect(pool.connect(owner).closeRound(player1.address))
      .to.emit(pool, "RoundClosed")
      .withArgs(0n, player1.address, totalPrize)

    // Assert: winner received prize pool
    expect(await token.balanceOf(player1.address)).to.equal(
      winnerBalanceBefore + totalPrize
    )
    // Pool is now empty
    expect(await token.balanceOf(poolAddress)).to.equal(0n)
    // Round is closed
    expect(await pool.isOpen()).to.equal(false)
  })

  // ─── Test 3: Non-owner cannot close round ────────────────────────────────────
  it("rejects non-owner closeRound", async () => {
    // Arrange: player1 deposits so round has players
    const depositAmount = ethers.parseEther("100")
    await token.connect(player1).approve(await pool.getAddress(), depositAmount)
    await pool.connect(player1).deposit(depositAmount)

    // Act + Assert: player2 cannot call closeRound
    await expect(
      pool.connect(player2).closeRound(player2.address)
    ).to.be.revertedWithCustomError(pool, "OwnableUnauthorizedAccount")
  })

  // ─── Test 4: Deposit rejected after round closed ──────────────────────────────
  it("rejects deposit after round closed", async () => {
    // Arrange: one player deposits so we can close
    const depositAmount = ethers.parseEther("100")
    await token.connect(player1).approve(await pool.getAddress(), depositAmount)
    await pool.connect(player1).deposit(depositAmount)

    // Close the round
    await pool.connect(owner).closeRound(player1.address)

    // Assert: further deposits are rejected
    await token.connect(player2).approve(await pool.getAddress(), depositAmount)
    await expect(
      pool.connect(player2).deposit(depositAmount)
    ).to.be.revertedWith("Round closed")
  })

  it("rejects deposit of zero amount", async () => {
    // Arrange + Act + Assert
    await expect(pool.connect(player1).deposit(0n)).to.be.revertedWith(
      "Amount must be > 0"
    )
  })

  it("rejects closeRound with no players", async () => {
    // Arrange: no deposits have been made
    // Act + Assert
    await expect(
      pool.connect(owner).closeRound(player1.address)
    ).to.be.revertedWith("No players")
  })

  // ─── Test 5: Opens new round after closing ────────────────────────────────────
  it("opens new round after closing", async () => {
    // Arrange: deposit and close round 0
    const depositAmount = ethers.parseEther("100")
    await token.connect(player1).approve(await pool.getAddress(), depositAmount)
    await pool.connect(player1).deposit(depositAmount)
    await pool.connect(owner).closeRound(player1.address)

    // Act: open round 1
    await expect(pool.connect(owner).openNewRound())
      .to.emit(pool, "RoundOpened")
      .withArgs(1n)

    // Assert: new round state is correct
    expect(await pool.roundId()).to.equal(1n)
    expect(await pool.isOpen()).to.equal(true)

    // Assert: can deposit in new round
    const newDeposit = ethers.parseEther("50")
    await token.connect(player2).approve(await pool.getAddress(), newDeposit)
    await pool.connect(player2).deposit(newDeposit)

    expect(await pool.totalDeposited(1n)).to.equal(newDeposit)
    // Round 0 deposits are unaffected
    expect(await pool.totalDeposited(0n)).to.equal(depositAmount)
  })

  it("rejects openNewRound while round is still open", async () => {
    // Arrange: round is currently open (initial state)
    // Act + Assert
    await expect(
      pool.connect(owner).openNewRound()
    ).to.be.revertedWith("Current round still open")
  })

  it("rejects double-close on same round", async () => {
    // Arrange
    const depositAmount = ethers.parseEther("100")
    await token.connect(player1).approve(await pool.getAddress(), depositAmount)
    await pool.connect(player1).deposit(depositAmount)
    await pool.connect(owner).closeRound(player1.address)

    // Act + Assert: second close should fail
    await expect(
      pool.connect(owner).closeRound(player2.address)
    ).to.be.revertedWith("Already closed")
  })
})
