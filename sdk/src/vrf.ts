import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { FlowNetwork, CONTRACT_ADDRESSES } from "./network-config.js";

export class VRFClient {
  constructor(private network: FlowNetwork) {}

  // Generate a cryptographically secure secret for commit/reveal
  generateSecret(): { secret: bigint; secretHex: string } {
    const bytes = crypto.getRandomValues(new Uint8Array(32));
    const secretHex = Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
    return { secret: BigInt("0x" + secretHex), secretHex };
  }

  async commit(secret: bigint, gameId: bigint): Promise<string> {
    const addr = CONTRACT_ADDRESSES[this.network].RandomVRF;
    return fcl.mutate({
      cadence: `
        import RandomVRF from ${addr}
        transaction(secret: UInt256, gameId: UInt64) {
          let playerAddress: Address
          prepare(signer: &Account) { self.playerAddress = signer.address }
          execute { RandomVRF.commit(secret: secret, gameId: gameId, player: self.playerAddress) }
        }
      `,
      args: (arg: typeof fcl.arg, t: any) => [
        arg(secret.toString(), t.UInt256),
        arg(gameId.toString(), t.UInt64),
      ],
      limit: 100,
    });
  }

  async reveal(secret: bigint, gameId: bigint): Promise<string> {
    const addr = CONTRACT_ADDRESSES[this.network].RandomVRF;
    return fcl.mutate({
      cadence: `
        import RandomVRF from ${addr}
        transaction(secret: UInt256, gameId: UInt64) {
          let playerAddress: Address
          prepare(signer: &Account) { self.playerAddress = signer.address }
          execute { RandomVRF.reveal(secret: secret, gameId: gameId, player: self.playerAddress) }
        }
      `,
      args: (arg: typeof fcl.arg, t: any) => [
        arg(secret.toString(), t.UInt256),
        arg(gameId.toString(), t.UInt64),
      ],
      limit: 200,
    });
  }
}
