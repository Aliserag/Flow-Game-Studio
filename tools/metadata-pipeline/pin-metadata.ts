import PinataSDK from "@pinata/sdk";
import { NFTMetadataSchema, NFTMetadata } from "./metadata-schema.js";
import * as fs from "fs";

const pinata = new PinataSDK({
  pinataApiKey: process.env.PINATA_API_KEY!,
  pinataSecretApiKey: process.env.PINATA_SECRET_KEY!,
});

export async function pinImage(imagePath: string, nftName: string): Promise<string> {
  const stream = fs.createReadStream(imagePath);
  const result = await pinata.pinFileToIPFS(stream, {
    pinataMetadata: { name: `${nftName}-image` },
    pinataOptions: { cidVersion: 1 },
  });
  return `ipfs://${result.IpfsHash}`;
}

export async function pinMetadata(metadata: NFTMetadata): Promise<string> {
  const validated = NFTMetadataSchema.parse(metadata);
  const result = await pinata.pinJSONToIPFS(validated, {
    pinataMetadata: { name: `${validated.name}-metadata` },
    pinataOptions: { cidVersion: 1 },
  });
  return `ipfs://${result.IpfsHash}`;
}

export async function generateMetadataURI(
  imagePath: string,
  metadata: Omit<NFTMetadata, "image">
): Promise<{ imageURI: string; metadataURI: string }> {
  const imageURI = await pinImage(imagePath, metadata.name);
  const metadataURI = await pinMetadata({ ...metadata, image: imageURI });
  return { imageURI, metadataURI };
}
