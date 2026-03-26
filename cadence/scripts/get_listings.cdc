// cadence/scripts/get_listings.cdc
// Returns the list of all active listing IDs from the Marketplace contract.
import "Marketplace"

access(all) fun main(): [UInt64] {
    return Marketplace.getActiveListings()
}
