// channel-client.ts
// Client-side state channel manager.
// Signs state updates off-chain using the player's private key.
// Only touches the blockchain to open or close the channel.

import { ec as EC } from "elliptic";
import { createHash } from "crypto";

const ec = new EC("p256");

export interface ChannelState {
  channelId: bigint;
  seqNum: bigint;
  balanceA: number;  // in token units
  balanceB: number;
  signatureA?: string;
  signatureB?: string;
}

export class StateChannelClient {
  private playerKey: EC.KeyPair;
  private playerAddress: string;

  constructor(privateKeyHex: string, address: string) {
    this.playerKey = ec.keyFromPrivate(privateKeyHex, "hex");
    this.playerAddress = address;
  }

  // Sign a state update — call after each game action
  signState(state: Omit<ChannelState, "signatureA" | "signatureB">): string {
    const stateHash = this.hashState(state);
    const sig = this.playerKey.sign(stateHash);
    return sig.toDER("hex");
  }

  // Verify the opponent's signature on a state
  verifyOpponentSignature(
    state: Omit<ChannelState, "signatureA" | "signatureB">,
    opponentPubKeyHex: string,
    signature: string
  ): boolean {
    const stateHash = this.hashState(state);
    const opponentKey = ec.keyFromPublic(opponentPubKeyHex, "hex");
    try {
      return opponentKey.verify(stateHash, Buffer.from(signature, "hex"));
    } catch { return false; }
  }

  private hashState(state: Omit<ChannelState, "signatureA" | "signatureB">): Buffer {
    const data = Buffer.concat([
      Buffer.from(state.channelId.toString().padStart(8, "0"), "ascii"),
      Buffer.from(state.seqNum.toString().padStart(8, "0"), "ascii"),
      Buffer.from(state.balanceA.toFixed(8), "ascii"),
      Buffer.from(state.balanceB.toFixed(8), "ascii"),
    ]);
    return createHash("sha256").update(data).digest();
  }

  // Create a game move: validate, sign, return new state
  applyMove(
    currentState: ChannelState,
    moveDeltaA: number,   // +/- change to player A's balance
    opponentPubKey: string,
    opponentSignature: string
  ): ChannelState {
    if (!this.verifyOpponentSignature(currentState, opponentPubKey, opponentSignature)) {
      throw new Error("Invalid opponent signature on current state");
    }
    const newState: Omit<ChannelState, "signatureA" | "signatureB"> = {
      channelId: currentState.channelId,
      seqNum: currentState.seqNum + 1n,
      balanceA: currentState.balanceA + moveDeltaA,
      balanceB: currentState.balanceB - moveDeltaA,
    };
    if (newState.balanceA < 0 || newState.balanceB < 0) {
      throw new Error("Invalid move: would result in negative balance");
    }
    const mySig = this.signState(newState);
    return { ...newState, signatureA: mySig };
  }
}
