// cadence/contracts/systems/Scheduler.cdc
//
// Epoch-based scheduler for time-driven game mechanics.
// "Scheduled transactions" on Flow are best modeled as epoch boundaries.

access(all) contract Scheduler {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------
    access(all) entitlement Admin

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    access(all) event EpochAdvanced(newEpoch: UInt64, blockHeight: UInt64)
    access(all) event ActionScheduled(id: UInt64, targetEpoch: UInt64, description: String)
    access(all) event ActionProcessed(id: UInt64, epoch: UInt64)

    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------
    access(all) struct ScheduledAction {
        access(all) let id: UInt64
        access(all) let targetEpoch: UInt64
        access(all) let description: String
        access(all) let payload: {String: AnyStruct}
        access(all) let submittedBy: Address
        access(all) var processed: Bool

        init(
            id: UInt64,
            targetEpoch: UInt64,
            description: String,
            payload: {String: AnyStruct},
            submittedBy: Address
        ) {
            self.id = id
            self.targetEpoch = targetEpoch
            self.description = description
            self.payload = payload
            self.submittedBy = submittedBy
            self.processed = false
        }
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    access(all) var currentEpoch: UInt64
    access(all) var epochBlockLength: UInt64
    access(all) var epochStartBlock: UInt64
    access(all) var totalActions: UInt64

    access(self) var pendingActions: {UInt64: ScheduledAction}
    access(self) var actionsByEpoch: {UInt64: [UInt64]}

    // -----------------------------------------------------------------------
    // Schedule an action for a future epoch
    // -----------------------------------------------------------------------
    access(all) fun scheduleAction(
        epochsFromNow: UInt64,
        description: String,
        payload: {String: AnyStruct},
        submitter: Address
    ): UInt64 {
        let targetEpoch = self.currentEpoch + epochsFromNow
        let id = self.totalActions

        let action = ScheduledAction(
            id: id,
            targetEpoch: targetEpoch,
            description: description,
            payload: payload,
            submittedBy: submitter
        )

        self.pendingActions[id] = action

        if self.actionsByEpoch[targetEpoch] == nil {
            self.actionsByEpoch[targetEpoch] = []
        }
        self.actionsByEpoch[targetEpoch]!.append(id)
        self.totalActions = self.totalActions + 1

        emit ActionScheduled(id: id, targetEpoch: targetEpoch, description: description)
        return id
    }

    // -----------------------------------------------------------------------
    // Process epoch — callable by anyone; advances epoch if block threshold met
    // -----------------------------------------------------------------------
    access(all) fun processEpoch(): UInt64 {
        let currentBlock = getCurrentBlock().height
        let blocksSinceEpochStart = currentBlock - self.epochStartBlock

        assert(
            blocksSinceEpochStart >= self.epochBlockLength,
            message: "Epoch not complete yet"
        )

        self.currentEpoch = self.currentEpoch + 1
        self.epochStartBlock = currentBlock
        emit EpochAdvanced(newEpoch: self.currentEpoch, blockHeight: currentBlock)

        var processed: UInt64 = 0
        let dueActions = self.actionsByEpoch[self.currentEpoch] ?? []
        for actionId in dueActions {
            if let action = self.pendingActions[actionId] {
                emit ActionProcessed(id: actionId, epoch: self.currentEpoch)
                self.pendingActions.remove(key: actionId)
                processed = processed + 1
            }
        }
        self.actionsByEpoch.remove(key: self.currentEpoch)
        return processed
    }

    // -----------------------------------------------------------------------
    // Admin resource
    // -----------------------------------------------------------------------
    access(all) resource AdminRef {
        access(all) fun setEpochBlockLength(_ length: UInt64) {
            Scheduler.epochBlockLength = length
        }
    }

    // -----------------------------------------------------------------------
    // Query
    // -----------------------------------------------------------------------
    access(all) fun getAction(_ id: UInt64): ScheduledAction? {
        return self.pendingActions[id]
    }

    access(all) fun getActionsForEpoch(_ epoch: UInt64): [UInt64] {
        return self.actionsByEpoch[epoch] ?? []
    }

    access(all) fun blocksUntilNextEpoch(): UInt64 {
        let elapsed = getCurrentBlock().height - self.epochStartBlock
        if elapsed >= self.epochBlockLength { return 0 }
        return self.epochBlockLength - elapsed
    }

    // -----------------------------------------------------------------------
    // Init
    // -----------------------------------------------------------------------
    init() {
        self.currentEpoch = 0
        self.epochBlockLength = 1000
        self.epochStartBlock = getCurrentBlock().height
        self.totalActions = 0
        self.pendingActions = {}
        self.actionsByEpoch = {}

        self.account.storage.save(<- create AdminRef(), to: /storage/SchedulerAdmin)
    }
}
