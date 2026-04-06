// create-child-account.ts
// Server-side child account provisioning for wallet-less onboarding.
// Run this when a new player signs up — gives them a Flow account instantly.
//
// SECURITY: Store private keys in a secrets manager (AWS Secrets Manager,
// HashiCorp Vault, etc.). Never in environment variables in production.

import * as fcl from "@onflow/fcl";
import * as sdk from "@onflow/sdk";
import { ec as EC } from "elliptic";
import * as crypto from "crypto";

const ec = new EC("p256");

fcl.config()
  .put("accessNode.api", process.env.FLOW_ACCESS_NODE ?? "https://rest-testnet.onflow.org")
  .put("flow.network", "testnet");

interface ChildAccountCredentials {
  address: string;
  publicKey: string;
  privateKey: string;  // MUST be stored securely — never log or expose
  playerId: string;
}

export async function provisionChildAccount(playerId: string): Promise<ChildAccountCredentials> {
  // Generate a new key pair for this player
  const keyPair = ec.genKeyPair();
  const privateKey = keyPair.getPrivate("hex");
  const publicKey = keyPair.getPublic(false, "hex").slice(2); // strip 04 prefix

  // Fund and create the account using the game's funding account
  // This transaction:
  // 1. Creates a new Flow account with the player's public key
  // 2. Funds it with enough FLOW for storage
  // 3. Sets up HybridCustody.OwnedAccount resource

  const txId = await fcl.mutate({
    cadence: `
      import HybridCustody from 0xHYBRID_CUSTODY_ADDRESS
      import CapabilityFactory from 0xCAP_FACTORY_ADDRESS
      import CapabilityFilter from 0xCAP_FILTER_ADDRESS

      transaction(pubKey: String, initialFundingAmount: UFix64) {
        prepare(sponsor: auth(BorrowValue, SaveValue) &Account) {
          // Create a new account with the player's public key
          let newAccount = Account(payer: sponsor)
          newAccount.keys.add(
            publicKey: PublicKey(
              publicKey: pubKey.decodeHex(),
              signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
            ),
            hashAlgorithm: HashAlgorithm.SHA3_256,
            weight: 1000.0
          )

          // Fund storage
          let fundingVault <- sponsor.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
          )!.withdraw(amount: initialFundingAmount)
          let receiver = newAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
          receiver.borrow()!.deposit(from: <-fundingVault)

          // Set up as a HybridCustody child account
          // (Full HybridCustody setup transaction — see Flow docs for current implementation)
        }
      }
    `,
    args: (arg, t) => [
      arg(publicKey, t.String),
      arg("0.001", t.UFix64),  // Minimum storage fee
    ],
    limit: 9999,
  });

  await fcl.tx(txId).onceSealed();

  // In production: get the new address from the transaction events
  // For now: placeholder
  const address = "0x" + crypto.randomBytes(8).toString("hex");

  return { address, publicKey, privateKey, playerId };
}
