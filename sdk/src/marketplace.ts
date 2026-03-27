import * as fcl from "@onflow/fcl";
import { FlowNetwork, CONTRACT_ADDRESSES } from "./network-config.js";

export interface Listing {
  listingId: string;
  nftId: string;
  price: string;
  seller: string;
}

export class MarketplaceClient {
  constructor(private network: FlowNetwork) {}

  async getActiveListings(): Promise<Listing[]> {
    const addr = CONTRACT_ADDRESSES[this.network].Marketplace;
    return fcl.query({
      cadence: `
        import Marketplace from ${addr}

        access(all) fun main(): [AnyStruct] {
          return Marketplace.getActiveListings()
        }
      `,
      args: (arg, t) => [],
    });
  }

  async createListing(nftId: number, price: string): Promise<string> {
    const addr = CONTRACT_ADDRESSES[this.network].Marketplace;
    return fcl.mutate({
      cadence: `
        import Marketplace from ${addr}
        import GameNFT from ${CONTRACT_ADDRESSES[this.network].GameNFT}

        transaction(nftId: UInt64, price: UFix64) {
          prepare(signer: auth(Storage) &Account) {
            let collection = signer.storage.borrow<auth(GameNFT.Withdraw) &GameNFT.Collection>(
              from: /storage/GameNFTCollection
            ) ?? panic("No NFT collection found")
            let nft <- collection.withdraw(withdrawID: nftId)
            Marketplace.createListing(nft: <-nft, price: price, seller: signer.address)
          }
        }
      `,
      args: (arg, t) => [
        arg(nftId.toString(), t.UInt64),
        arg(price, t.UFix64),
      ],
      limit: 200,
    });
  }

  async buyListing(listingId: number): Promise<string> {
    const addr = CONTRACT_ADDRESSES[this.network].Marketplace;
    return fcl.mutate({
      cadence: `
        import Marketplace from ${addr}
        import GameToken from ${CONTRACT_ADDRESSES[this.network].GameToken}
        import FungibleToken from ${CONTRACT_ADDRESSES[this.network].FungibleToken}

        transaction(listingId: UInt64) {
          prepare(signer: auth(Storage) &Account) {
            let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
              from: /storage/GameTokenVault
            ) ?? panic("No GameToken vault found")
            Marketplace.buyListing(listingId: listingId, payment: <-vault.withdraw(amount: 0.0))
          }
        }
      `,
      args: (arg, t) => [arg(listingId.toString(), t.UInt64)],
      limit: 200,
    });
  }
}
