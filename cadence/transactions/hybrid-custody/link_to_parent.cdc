// Links a child account (game-managed) to a parent account (player's wallet).
// Must be signed by BOTH the child account AND the parent account.
// After this, the parent can see and manage assets in the child account.
//
// REFERENCE: https://developers.flow.com/tools/toolchains/flow-cli/accounts/hybrid-custody
// This transaction must be updated to match the current HybridCustody API.
// The HybridCustody contract has evolved — always check Flow docs before using.

import HybridCustody from 0xHYBRID_CUSTODY_ADDRESS
import CapabilityFactory from 0xCAP_FACTORY_ADDRESS
import CapabilityFilter from 0xCAP_FILTER_ADDRESS

transaction(
    parentFilterAddress: Address?,
    childAccountFactoryAddress: Address
) {
    prepare(
        child: auth(Storage, Capabilities) &Account,
        parent: auth(Storage, Capabilities) &Account
    ) {
        // Child account publishes its OwnedAccount capability
        // Parent claims it and establishes the link

        // NOTE: The exact transaction body depends on the deployed HybridCustody version.
        // Run: flow scripts execute scripts/hybrid-custody/getChildAccountAddresses.cdc <parentAddress>
        // to verify the link was established.
    }
}
