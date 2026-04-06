// setup_child_account.cdc
// Sets up a new account as a HybridCustody child account.
// Called by the game server after creating the account — establishes
// the OwnedAccount resource that enables future parent linking.
//
// IMPORTANT: Always verify HybridCustody contract addresses from Flow docs:
// https://developers.flow.com/tools/toolchains/flow-cli/accounts/hybrid-custody

import HybridCustody from 0xHYBRID_CUSTODY_ADDRESS
import CapabilityFactory from 0xCAP_FACTORY_ADDRESS
import CapabilityFilter from 0xCAP_FILTER_ADDRESS
import MetadataViews from 0xMETADATA_VIEWS_ADDRESS

transaction(
    name: String,
    description: String,
    thumbnail: String
) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        // Skip if already set up
        if acct.storage.borrow<&HybridCustody.OwnedAccount>(
            from: HybridCustody.OwnedAccountStoragePath
        ) != nil {
            return
        }

        // Create and save the OwnedAccount resource
        let ownedAccount <- HybridCustody.createOwnedAccount(acct: acct)
        acct.storage.save(<-ownedAccount, to: HybridCustody.OwnedAccountStoragePath)

        // Publish public capability for parent discovery
        acct.capabilities.unpublish(HybridCustody.OwnedAccountPublicPath)
        let cap = acct.capabilities.storage.issue<&{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(
            HybridCustody.OwnedAccountStoragePath
        )
        acct.capabilities.publish(cap, at: HybridCustody.OwnedAccountPublicPath)
    }
}
