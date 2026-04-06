// get_child_accounts.cdc
// Returns all child accounts linked to a parent address.
// Use to display a player's managed game accounts in a wallet UI.

import HybridCustody from 0xHYBRID_CUSTODY_ADDRESS

access(all) fun main(parentAddress: Address): [Address] {
    let account = getAccount(parentAddress)

    // Check if parent has a HybridCustody manager
    let managerRef = account.capabilities
        .borrow<&{HybridCustody.ManagerPublic}>(HybridCustody.ManagerPublicPath)

    if managerRef == nil {
        return []
    }

    return managerRef!.getChildAddresses()
}
