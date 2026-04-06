// Off-chain tool: Given a list of Flow addresses, generate a Merkle tree
// and output the root + proof for each address.
// Usage: npx ts-node generate_merkle_root.ts addresses.json output.json

import { MerkleTree } from "merkletreejs";
import { keccak256 } from "js-sha3";
import * as fs from "fs";

function flowAddrToLeaf(addr: string): Buffer {
  // Normalize: strip 0x, pad to 32 bytes
  const hex = addr.replace("0x", "").padStart(64, "0");
  return Buffer.from(keccak256.arrayBuffer(Buffer.from(hex, "hex")));
}

const [, , inputPath, outputPath] = process.argv;
if (!inputPath || !outputPath) {
  console.error("Usage: ts-node generate_merkle_root.ts <addresses.json> <output.json>");
  process.exit(1);
}

const addresses: string[] = JSON.parse(fs.readFileSync(inputPath, "utf8"));
const leaves = addresses.map(flowAddrToLeaf);
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const root = tree.getRoot().toString("hex");

const result = {
  root,
  rootBytes: Array.from(tree.getRoot()),
  proofs: addresses.map((addr) => {
    const leaf = flowAddrToLeaf(addr);
    const proof = tree.getProof(leaf);
    return {
      address: addr,
      proof: proof.map((p) => Array.from(p.data)),
      pathIndices: proof.map((p) => (p.position === "left" ? 0 : 1)),
    };
  }),
};

fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
console.log(`Root: 0x${root}`);
console.log(`Generated proofs for ${addresses.length} addresses → ${outputPath}`);
