import * as fcl from "@onflow/fcl";
import { FlowNetwork, CONTRACT_ADDRESSES } from "./network-config.js";

export class TokenClient {
  constructor(private network: FlowNetwork) {}

  async getBalance(address: string): Promise<string> {
    const addr = CONTRACT_ADDRESSES[this.network].GameToken;
    return fcl.query({
      cadence: `
        import GameToken from ${addr}
        import FungibleToken from ${CONTRACT_ADDRESSES[this.network].FungibleToken}

        access(all) fun main(address: Address): UFix64 {
          let account = getAccount(address)
          let vault = account.capabilities
            .borrow<&{FungibleToken.Balance}>(/public/GameTokenBalance)
            ?? panic("No GameToken vault found")
          return vault.balance
        }
      `,
      args: (arg, t) => [arg(address, t.Address)],
    });
  }

  async transfer(recipientAddress: string, amount: string): Promise<string> {
    const addr = CONTRACT_ADDRESSES[this.network].GameToken;
    return fcl.mutate({
      cadence: `
        import GameToken from ${addr}
        import FungibleToken from ${CONTRACT_ADDRESSES[this.network].FungibleToken}

        transaction(recipient: Address, amount: UFix64) {
          let vault: @{FungibleToken.Vault}
          prepare(signer: auth(Storage) &Account) {
            let senderVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
              from: /storage/GameTokenVault
            ) ?? panic("No GameToken vault found")
            self.vault <- senderVault.withdraw(amount: amount)
          }
          execute {
            let recipient = getAccount(recipient)
            let receiverRef = recipient.capabilities
              .borrow<&{FungibleToken.Receiver}>(/public/GameTokenReceiver)
              ?? panic("Recipient has no GameToken receiver")
            receiverRef.deposit(from: <-self.vault)
          }
        }
      `,
      args: (arg, t) => [
        arg(recipientAddress, t.Address),
        arg(amount, t.UFix64),
      ],
      limit: 100,
    });
  }
}
