import "GameToken"
import "EmergencyPause"

access(all) contract Governance {

    access(all) entitlement Executor
    access(all) entitlement Proposer

    access(all) enum ProposalStatus: UInt8 {
        access(all) case pending    // 0: voting open
        access(all) case succeeded  // 1: passed quorum and majority
        access(all) case defeated   // 2: failed quorum or majority
        access(all) case executed   // 3: action carried out
        access(all) case cancelled  // 4: proposer withdrew
    }

    access(all) struct Proposal {
        access(all) let id: UInt64
        access(all) let proposer: Address
        access(all) let title: String
        access(all) let description: String
        access(all) let actionType: String   // e.g., "update_price", "treasury_transfer"
        access(all) let actionPayload: String // JSON-encoded action params
        access(all) let snapshotBlock: UInt64
        access(all) let voteEndBlock: UInt64
        access(all) var yesVotes: UFix64
        access(all) var noVotes: UFix64
        access(all) var status: ProposalStatus
        access(all) var voters: {Address: Bool}  // address -> voted yes?

        access(contract) fun addYesVote(_ weight: UFix64) { self.yesVotes = self.yesVotes + weight }
        access(contract) fun addNoVote(_ weight: UFix64) { self.noVotes = self.noVotes + weight }
        access(contract) fun setVoter(_ voter: Address, _ support: Bool) { self.voters[voter] = support }
        access(contract) fun setStatus(_ s: ProposalStatus) { self.status = s }

        init(id: UInt64, proposer: Address, title: String, description: String,
             actionType: String, actionPayload: String, voteEndBlock: UInt64) {
            self.id = id; self.proposer = proposer; self.title = title
            self.description = description; self.actionType = actionType
            self.actionPayload = actionPayload
            self.snapshotBlock = getCurrentBlock().height
            self.voteEndBlock = voteEndBlock
            self.yesVotes = 0.0; self.noVotes = 0.0
            self.status = ProposalStatus.pending
            self.voters = {}
        }
    }

    // Governance parameters (updateable via governance itself)
    access(all) var votingPeriodBlocks: UInt64   // default: ~3 days = 108000 blocks
    access(all) var quorumPct: UFix64             // default: 4.0% of total supply
    access(all) var passMajorityPct: UFix64        // default: 51.0%
    access(all) var proposalThreshold: UFix64     // min tokens to propose

    access(all) var proposals: {UInt64: Proposal}
    access(all) var nextProposalId: UInt64
    access(all) let AdminStoragePath: StoragePath

    access(all) event ProposalCreated(id: UInt64, proposer: Address, title: String)
    access(all) event VoteCast(proposalId: UInt64, voter: Address, support: Bool, weight: UFix64)
    access(all) event ProposalFinalized(id: UInt64, status: UInt8)
    access(all) event ProposalExecuted(id: UInt64, actionType: String)

    access(all) fun createProposal(
        proposer: Address,
        title: String,
        description: String,
        actionType: String,
        actionPayload: String,
        voterBalance: UFix64
    ): UInt64 {
        pre {
            voterBalance >= Governance.proposalThreshold:
                "Insufficient tokens to propose (need ".concat(Governance.proposalThreshold.toString()).concat(")")
        }
        EmergencyPause.assertNotPaused()
        let id = Governance.nextProposalId
        Governance.nextProposalId = id + 1
        let endBlock = getCurrentBlock().height + Governance.votingPeriodBlocks
        let proposal = Proposal(
            id: id, proposer: proposer, title: title, description: description,
            actionType: actionType, actionPayload: actionPayload, voteEndBlock: endBlock
        )
        Governance.proposals[id] = proposal
        emit ProposalCreated(id: id, proposer: proposer, title: title)
        return id
    }

    access(all) fun castVote(proposalId: UInt64, voter: Address, support: Bool, weight: UFix64) {
        pre { weight > 0.0: "Zero voting weight" }
        EmergencyPause.assertNotPaused()

        var proposal = Governance.proposals[proposalId] ?? panic("Unknown proposal")
        assert(proposal.status == ProposalStatus.pending, message: "Voting closed")
        assert(getCurrentBlock().height <= proposal.voteEndBlock, message: "Voting period ended")
        assert(proposal.voters[voter] == nil, message: "Already voted")

        proposal.setVoter(voter, support)
        if support { proposal.addYesVote(weight) }
        else { proposal.addNoVote(weight) }
        Governance.proposals[proposalId] = proposal
        emit VoteCast(proposalId: proposalId, voter: voter, support: support, weight: weight)
    }

    // Finalize after voting period ends
    access(all) fun finalizeProposal(proposalId: UInt64, totalSupply: UFix64) {
        var proposal = Governance.proposals[proposalId] ?? panic("Unknown proposal")
        assert(getCurrentBlock().height > proposal.voteEndBlock, message: "Voting still open")
        assert(proposal.status == ProposalStatus.pending, message: "Already finalized")

        let totalVotes = proposal.yesVotes + proposal.noVotes
        let quorum = totalSupply * (Governance.quorumPct / 100.0)
        let passed = totalVotes >= quorum
            && (proposal.yesVotes / totalVotes) * 100.0 >= Governance.passMajorityPct

        proposal.setStatus(passed ? ProposalStatus.succeeded : ProposalStatus.defeated)
        Governance.proposals[proposalId] = proposal
        emit ProposalFinalized(id: proposalId, status: proposal.status.rawValue)
    }

    access(all) resource Admin {
        access(Executor) fun executeProposal(proposalId: UInt64) {
            var proposal = Governance.proposals[proposalId] ?? panic("Unknown proposal")
            assert(proposal.status == ProposalStatus.succeeded, message: "Proposal not succeeded")
            // Action dispatch — executor contract reads actionType and actionPayload
            // and routes to the appropriate admin transaction
            proposal.setStatus(ProposalStatus.executed)
            Governance.proposals[proposalId] = proposal
            emit ProposalExecuted(id: proposalId, actionType: proposal.actionType)
        }
    }

    init() {
        self.votingPeriodBlocks = 108_000  // ~3 days at ~2.4 sec/block
        self.quorumPct = 4.0
        self.passMajorityPct = 51.0
        self.proposalThreshold = 1000.0    // Must hold 1000 tokens to propose
        self.proposals = {}
        self.nextProposalId = 0
        self.AdminStoragePath = /storage/GovernanceAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}
