import { z } from "zod";

export const AttributeSchema = z.object({
  trait_type: z.string(),
  value: z.union([z.string(), z.number()]),
  display_type: z.optional(z.enum(["number","boost_number","boost_percentage","date"])),
});

export const NFTMetadataSchema = z.object({
  name: z.string().min(1).max(64),
  description: z.string().max(1000),
  image: z.string().startsWith("ipfs://"),
  external_url: z.optional(z.string().url()),
  attributes: z.array(AttributeSchema).max(30),
  contract_address: z.string().regex(/^0x[0-9a-f]{16}$/i),
  nft_id: z.optional(z.number().int().nonneg()),
  edition: z.optional(z.object({
    number: z.number().int().positive(),
    max: z.optional(z.number().int().positive()),
  })),
});

export type NFTMetadata = z.infer<typeof NFTMetadataSchema>;
