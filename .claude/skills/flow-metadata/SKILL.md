---
name: flow-metadata
description: "Generate MetadataViews resolver implementations for Flow NFT contracts, IPFS metadata JSON templates, and pinning commands. Invoke as /flow-metadata <ContractName> [--traits 'key:type,...']."
argument-hint: "<ContractName> [--traits 'key:string,level:number']"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# /flow-metadata

Generate MetadataViews resolvers, IPFS metadata templates, and pinning commands for Flow NFTs.

**Read first:** `docs/flow-reference/standard-contracts.md`, `docs/flow-reference/VERSION.md`

## Usage

```
/flow-metadata GameNFT --traits "weapon_type:string,damage:number,rarity:string"
```

## What This Generates

### 1. Cadence `resolveView()` implementation

Covers: `Display`, `Editions`, `Traits`, `Royalties`, `NFTCollectionData`, `ExternalURL`.

```cadence
access(all) fun resolveView(_ view: Type): AnyStruct? {
    switch view {
        case Type<MetadataViews.Display>():
            return MetadataViews.Display(
                name: self.name,
                description: self.description,
                thumbnail: MetadataViews.HTTPFile(url: self.thumbnailURL)
            )
        case Type<MetadataViews.Editions>():
            let info = MetadataViews.Edition(name: "Series 1", number: self.serialNumber, max: nil)
            return MetadataViews.Editions([info])
        case Type<MetadataViews.Traits>():
            return MetadataViews.dictToTraits(dict: self.attributes, excludedNames: nil)
        case Type<MetadataViews.Royalties>():
            return MetadataViews.Royalties(self.royalties)
        case Type<MetadataViews.NFTCollectionData>():
            return MetadataViews.NFTCollectionData(
                storagePath: CONTRACT_NAME.CollectionStoragePath,
                publicPath: CONTRACT_NAME.CollectionPublicPath,
                publicCollection: Type<&CONTRACT_NAME.Collection>(),
                publicLinkedType: Type<&CONTRACT_NAME.Collection>(),
                createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                    return <- CONTRACT_NAME.createEmptyCollection(nftType: Type<@CONTRACT_NAME.NFT>())
                })
            )
    }
    return nil
}
```

**Replace `CONTRACT_NAME` with the actual contract name before saving.**

### 2. `getViews()` implementation

```cadence
access(all) fun getViews(): [Type] {
    return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Editions>(),
        Type<MetadataViews.Traits>(),
        Type<MetadataViews.Royalties>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.ExternalURL>()
    ]
}
```

### 3. IPFS metadata JSON template

```json
{
  "name": "[NFT Name]",
  "description": "[Description — max 1000 chars]",
  "image": "ipfs://[IMAGE_CID]",
  "external_url": "https://[your-game-site]/nft/[id]",
  "contract_address": "0x[16-char-hex]",
  "nft_id": 0,
  "edition": { "number": 1, "max": 10000 },
  "attributes": [
    { "trait_type": "weapon_type", "value": "sword" },
    { "trait_type": "damage", "value": 42, "display_type": "number" },
    { "trait_type": "rarity", "value": "legendary" }
  ]
}
```

### 4. Pinning command

```bash
PINATA_API_KEY=your_key PINATA_SECRET_KEY=your_secret \
  npx ts-node tools/metadata-pipeline/pin-metadata.ts
```

For batch pinning:
```bash
PINATA_API_KEY=your_key PINATA_SECRET_KEY=your_secret \
  npx ts-node tools/metadata-pipeline/batch-pin.ts
```

## Workflow

1. Prepare images → pin with `pinImage()` → get `ipfs://CID` URLs
2. Fill metadata template with actual CIDs
3. Validate with `NFTMetadataSchema.parse(metadata)` (Zod throws on invalid)
4. Pin metadata JSON → get `ipfs://CID` for `imageURL` field in NFT
5. Use that CID as the `imageURL` argument to `mint_game_nft.cdc`

## Notes

- Always use CIDv1 (base32) — the `pinataOptions: { cidVersion: 1 }` setting ensures this
- Store original CIDs in `tools/metadata-pipeline/minted-cids.json` for audit trail
- Pinata free tier: 1GB storage, 100 pins/day — upgrade for production launches
