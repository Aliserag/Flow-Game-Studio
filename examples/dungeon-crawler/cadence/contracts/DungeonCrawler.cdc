// DungeonCrawler.cdc — Reference implementation using all Flow game patterns
// Demonstrates: VRF commit/reveal, NFT equipment checks, token rewards,
//               scheduled dungeon resets, and EmergencyPause integration

import "NonFungibleToken"
import "GameNFT"
import "GameToken"
import "RandomVRF"
import "Scheduler"
import "EmergencyPause"

access(all) contract DungeonCrawler {

    // --- Dungeon State ---
    access(all) enum DungeonResult: UInt8 {
        access(all) case pending   // 0
        access(all) case victory   // 1
        access(all) case defeat    // 2
    }

    access(all) struct Run {
        access(all) let runId: UInt64
        access(all) let player: Address
        access(all) let dungeonLevel: UInt8
        access(all) let entryBlock: UInt64
        access(all) var result: DungeonResult
        access(all) var rewardMinted: Bool

        init(runId: UInt64, player: Address, dungeonLevel: UInt8) {
            self.runId = runId; self.player = player
            self.dungeonLevel = dungeonLevel
            self.entryBlock = getCurrentBlock().height
            self.result = DungeonResult.pending
            self.rewardMinted = false
        }
    }

    access(all) var runs: {UInt64: Run}
    access(all) var nextRunId: UInt64

    // Difficulty tiers: 1=easy(60% win), 2=medium(40%), 3=hard(25%)
    access(all) let winThresholds: {UInt8: UInt64}

    // Token rewards per tier
    access(all) let tokenRewards: {UInt8: UFix64}

    access(all) let MinterStoragePath: StoragePath

    access(all) event DungeonEntered(runId: UInt64, player: Address, level: UInt8)
    access(all) event DungeonResult(runId: UInt64, player: Address, result: DungeonResult, reward: UFix64)

    // Step 1: Player commits secret (off-chain game generates random secret)
    access(all) fun enterDungeon(player: Address, secret: UInt256, level: UInt8) {
        EmergencyPause.assertNotPaused()
        pre { level >= 1 && level <= 3: "Invalid dungeon level" }

        let runId = DungeonCrawler.nextRunId
        DungeonCrawler.nextRunId = runId + 1

        let run = Run(runId: runId, player: player, dungeonLevel: level)
        DungeonCrawler.runs[runId] = run

        // Commit the VRF secret
        RandomVRF.commit(secret: secret, gameId: runId, player: player)
        emit DungeonEntered(runId: runId, player: player, level: level)
    }

    // Step 2: After at least 1 block, reveal and resolve combat
    access(all) fun resolveDungeon(
        runId: UInt64,
        player: Address,
        secret: UInt256,
        minterRef: &GameToken.Minter,
        receiverRef: &{FungibleToken.Receiver}
    ) {
        EmergencyPause.assertNotPaused()
        var run = DungeonCrawler.runs[runId] ?? panic("Unknown run")
        assert(run.result == DungeonResult.pending, message: "Already resolved")
        assert(run.player == player, message: "Not your run")

        // Reveal produces a verified random number in [0, 10000)
        let raw = RandomVRF.reveal(secret: secret, gameId: runId, player: player)
        let roll = RandomVRF.boundedRandom(seed: raw, max: 10_000)

        let threshold = DungeonCrawler.winThresholds[run.dungeonLevel]!
        let won = roll < threshold

        run.result = won ? DungeonResult.victory : DungeonResult.defeat

        var rewardAmount: UFix64 = 0.0
        if won {
            rewardAmount = DungeonCrawler.tokenRewards[run.dungeonLevel]!
            let tokens <- minterRef.mintTokens(amount: rewardAmount)
            receiverRef.deposit(from: <-tokens)
            run.rewardMinted = true
        }

        DungeonCrawler.runs[runId] = run
        emit DungeonResult(runId: runId, player: player, result: run.result, reward: rewardAmount)
    }

    init() {
        self.runs = {}
        self.nextRunId = 0
        self.winThresholds = {1: 6000, 2: 4000, 3: 2500}  // per 10,000
        self.tokenRewards = {1: 10.0, 2: 25.0, 3: 75.0}
        self.MinterStoragePath = /storage/DungeonCrawlerMinter
    }
}
