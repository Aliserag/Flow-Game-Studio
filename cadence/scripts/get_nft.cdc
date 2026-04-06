// cadence/scripts/get_nft.cdc
// Returns NFT metadata for a given owner and NFT ID
import "NonFungibleToken"
import "GameNFT"
import "MetadataViews"

access(all) fun main(address: Address, id: UInt64): {String: AnyStruct}? {
    let account = getAccount(address)
    let collection = account.capabilities
        .get<&GameNFT.Collection>(GameNFT.CollectionPublicPath)
        .borrow()
        ?? return nil

    let nft = collection.borrowNFT(id) ?? return nil

    let display = nft.resolveView(Type<MetadataViews.Display>())
        as! MetadataViews.Display?

    return {
        "id": id,
        "name": display?.name ?? "Unknown",
        "description": display?.description ?? "",
        "imageURL": (display?.thumbnail as! MetadataViews.HTTPFile?)?.url ?? ""
    }
}
