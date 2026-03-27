import * as fcl from "@onflow/fcl";
import { FlowNetwork, CONTRACT_ADDRESSES } from "./network-config.js";

export interface NFTMetadata {
  id: string;
  name: string;
  description: string;
  thumbnail: string;
  rarity: string;
  power: string;
}

export class NFTClient {
  constructor(private network: FlowNetwork) {}

  async getNFTsForAccount(address: string): Promise<NFTMetadata[]> {
    const addr = CONTRACT_ADDRESSES[this.network].GameNFT;
    return fcl.query({
      cadence: `
        import GameNFT from ${addr}
        import MetadataViews from ${CONTRACT_ADDRESSES[this.network].MetadataViews}

        access(all) fun main(address: Address): [AnyStruct] {
          let account = getAccount(address)
          let collectionRef = account.capabilities
            .borrow<&GameNFT.Collection>(/public/GameNFTCollection)
            ?? panic("No collection found")
          let ids = collectionRef.getIDs()
          var results: [AnyStruct] = []
          for id in ids {
            let nft = collectionRef.borrowNFT(id)
            results.append(nft.id)
          }
          return results
        }
      `,
      args: (arg, t) => [arg(address, t.Address)],
    });
  }

  async mintNFT(
    recipientAddress: string,
    name: string,
    description: string,
    thumbnail: string,
    rarity: string,
    power: number
  ): Promise<string> {
    const addr = CONTRACT_ADDRESSES[this.network].GameNFT;
    return fcl.mutate({
      cadence: `
        import GameNFT from ${addr}
        transaction(
          recipient: Address,
          name: String,
          description: String,
          thumbnail: String,
          rarity: String,
          power: UInt64
        ) {
          let minter: &GameNFT.Minter
          prepare(signer: auth(Storage) &Account) {
            self.minter = signer.storage.borrow<&GameNFT.Minter>(from: /storage/GameNFTMinter)
              ?? panic("No minter found")
          }
          execute {
            let recipient = getAccount(recipient)
            let collection = recipient.capabilities
              .borrow<&{GameNFT.CollectionPublic}>(/public/GameNFTCollection)
              ?? panic("Recipient has no collection")
            self.minter.mintNFT(
              recipient: collection,
              name: name,
              description: description,
              thumbnail: thumbnail,
              rarity: rarity,
              power: power
            )
          }
        }
      `,
      args: (arg, t) => [
        arg(recipientAddress, t.Address),
        arg(name, t.String),
        arg(description, t.String),
        arg(thumbnail, t.String),
        arg(rarity, t.String),
        arg(power.toString(), t.UInt64),
      ],
      limit: 200,
    });
  }
}
