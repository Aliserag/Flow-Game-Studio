// StateChannel.cdc
// Two-party state channels for off-chain game state with on-chain settlement.
//
// Protocol:
// 1. Both players deposit GameToken escrow into open_channel.cdc
// 2. Players sign game state updates off-chain (seqNum must increase monotonically)
// 3. Either player closes: submit latest mutually-signed state
// 4. Dispute window: opponent can challenge with a higher seqNum state
// 5. After dispute window: funds distributed per final state

import "FungibleToken"
import "GameToken"
import "EmergencyPause"

access(all) contract StateChannel {

    access(all) entitlement ChannelAdmin

    access(all) enum ChannelStatus: UInt8 {
        access(all) case open      // 0: active, off-chain signing in progress
        access(all) case closing   // 1: close submitted, dispute window active
        access(all) case settled   // 2: funds distributed
        access(all) case disputed  // 3: dispute filed, arbiter resolving
    }

    access(all) struct Channel {
        access(all) let channelId: UInt64
        access(all) let playerA: Address
        access(all) let playerB: Address
        access(all) let depositA: UFix64
        access(all) let depositB: UFix64
        access(all) var status: ChannelStatus
        access(all) var latestSeqNum: UInt64
        access(all) var latestStateHash: [UInt8]  // hash of game state at latestSeqNum
        access(all) var balanceA: UFix64           // current channel balance for A
        access(all) var balanceB: UFix64
        access(all) var closeInitiatedAtBlock: UInt64
        access(all) let disputeWindowBlocks: UInt64  // default: ~10 minutes = 250 blocks

        init(channelId: UInt64, playerA: Address, playerB: Address,
             depositA: UFix64, depositB: UFix64) {
            self.channelId = channelId; self.playerA = playerA; self.playerB = playerB
            self.depositA = depositA; self.depositB = depositB
            self.status = ChannelStatus.open
            self.latestSeqNum = 0; self.latestStateHash = []
            self.balanceA = depositA; self.balanceB = depositB
            self.closeInitiatedAtBlock = 0; self.disputeWindowBlocks = 250
        }
    }

    access(all) var channels: {UInt64: Channel}
    access(all) var nextChannelId: UInt64
    // Escrow vault holds both players' deposits
    access(all) let EscrowStoragePath: StoragePath
    access(all) let AdminStoragePath: StoragePath

    access(all) event ChannelOpened(channelId: UInt64, playerA: Address, playerB: Address)
    access(all) event ChannelCloseInitiated(channelId: UInt64, seqNum: UInt64, initiator: Address)
    access(all) event ChannelDisputed(channelId: UInt64, disputerSeqNum: UInt64)
    access(all) event ChannelSettled(channelId: UInt64, payoutA: UFix64, payoutB: UFix64)

    // Open: both players deposit into escrow
    access(all) fun openChannel(
        playerA: Address, playerB: Address,
        depositA: @{FungibleToken.Vault},
        depositB: @{FungibleToken.Vault}
    ): UInt64 {
        EmergencyPause.assertNotPaused()
        let id = StateChannel.nextChannelId
        StateChannel.nextChannelId = id + 1

        let amtA = depositA.balance
        let amtB = depositB.balance

        // Deposit both into escrow vault
        let escrow = StateChannel.account.storage.borrow<&{FungibleToken.Receiver}>(
            from: StateChannel.EscrowStoragePath
        )!
        escrow.deposit(from: <-depositA)
        escrow.deposit(from: <-depositB)

        StateChannel.channels[id] = Channel(
            channelId: id, playerA: playerA, playerB: playerB,
            depositA: amtA, depositB: amtB
        )
        emit ChannelOpened(channelId: id, playerA: playerA, playerB: playerB)
        return id
    }

    // Close: submit final state signed by both parties
    // stateHash = keccak256(channelId || seqNum || balanceA || balanceB)
    // Both signatures verified off-chain (Cadence lacks ECDSA signature recovery currently)
    // In production: use a trusted arbiter account for signature verification
    access(all) fun initiateClose(
        channelId: UInt64,
        seqNum: UInt64,
        balanceA: UFix64,
        balanceB: UFix64,
        stateHash: [UInt8],
        initiator: Address
    ) {
        var channel = StateChannel.channels[channelId] ?? panic("Unknown channel")
        assert(channel.status == ChannelStatus.open, message: "Channel not open")
        assert(initiator == channel.playerA || initiator == channel.playerB, message: "Not a participant")
        assert(seqNum > channel.latestSeqNum, message: "State is not newer than current")
        assert(balanceA + balanceB == channel.depositA + channel.depositB, message: "Balance mismatch")

        channel.status = ChannelStatus.closing
        channel.latestSeqNum = seqNum
        channel.latestStateHash = stateHash
        channel.balanceA = balanceA; channel.balanceB = balanceB
        channel.closeInitiatedAtBlock = getCurrentBlock().height
        StateChannel.channels[channelId] = channel
        emit ChannelCloseInitiated(channelId: channelId, seqNum: seqNum, initiator: initiator)
    }

    // Dispute: opponent provides a newer state during the dispute window
    access(all) fun dispute(
        channelId: UInt64,
        newerSeqNum: UInt64,
        balanceA: UFix64,
        balanceB: UFix64,
        stateHash: [UInt8],
        disputer: Address
    ) {
        var channel = StateChannel.channels[channelId] ?? panic("Unknown channel")
        assert(channel.status == ChannelStatus.closing, message: "Not in closing state")
        assert(getCurrentBlock().height <= channel.closeInitiatedAtBlock + channel.disputeWindowBlocks,
            message: "Dispute window closed")
        assert(newerSeqNum > channel.latestSeqNum, message: "Not a newer state")
        assert(balanceA + balanceB == channel.depositA + channel.depositB, message: "Balance mismatch")

        channel.latestSeqNum = newerSeqNum
        channel.latestStateHash = stateHash
        channel.balanceA = balanceA; channel.balanceB = balanceB
        channel.status = ChannelStatus.disputed
        StateChannel.channels[channelId] = channel
        emit ChannelDisputed(channelId: channelId, disputerSeqNum: newerSeqNum)
    }

    // Settle: after dispute window, distribute funds
    access(all) fun settle(
        channelId: UInt64,
        receiverA: &{FungibleToken.Receiver},
        receiverB: &{FungibleToken.Receiver}
    ) {
        var channel = StateChannel.channels[channelId] ?? panic("Unknown channel")
        let windowClosed = getCurrentBlock().height > channel.closeInitiatedAtBlock + channel.disputeWindowBlocks
        assert(channel.status == ChannelStatus.closing && windowClosed || channel.status == ChannelStatus.disputed,
            message: "Cannot settle yet")

        channel.status = ChannelStatus.settled

        let escrow = StateChannel.account.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
            from: StateChannel.EscrowStoragePath
        )!
        if channel.balanceA > 0.0 {
            receiverA.deposit(from: <-escrow.withdraw(amount: channel.balanceA))
        }
        if channel.balanceB > 0.0 {
            receiverB.deposit(from: <-escrow.withdraw(amount: channel.balanceB))
        }

        StateChannel.channels[channelId] = channel
        emit ChannelSettled(channelId: channelId, payoutA: channel.balanceA, payoutB: channel.balanceB)
    }

    init() {
        self.channels = {}; self.nextChannelId = 0
        self.EscrowStoragePath = /storage/StateChannelEscrow
        self.AdminStoragePath = /storage/StateChannelAdmin
        self.account.storage.save(
            <-GameToken.createEmptyVault(vaultType: Type<@GameToken.Vault>()),
            to: self.EscrowStoragePath
        )
        self.account.storage.save(<-create StateChannel_Admin(), to: self.AdminStoragePath)
    }

    access(all) resource StateChannel_Admin {}
}
