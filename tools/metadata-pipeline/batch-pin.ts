import { generateMetadataURI } from "./pin-metadata.js";
import { NFTMetadata } from "./metadata-schema.js";

interface BatchItem {
  imagePath: string;
  metadata: Omit<NFTMetadata, "image">;
}

export async function batchPin(
  items: BatchItem[],
  concurrency = 5
): Promise<Array<{ index: number; imageURI: string; metadataURI: string; error?: string }>> {
  const results: Array<{ index: number; imageURI: string; metadataURI: string; error?: string }> = [];

  for (let i = 0; i < items.length; i += concurrency) {
    const chunk = items.slice(i, i + concurrency);
    const settled = await Promise.allSettled(
      chunk.map((item, j) =>
        generateMetadataURI(item.imagePath, item.metadata).then((uris) => ({ index: i + j, ...uris }))
      )
    );
    for (let j = 0; j < settled.length; j++) {
      const r = settled[j];
      if (r.status === "fulfilled") results.push(r.value);
      else results.push({ index: i + j, imageURI: "", metadataURI: "", error: String(r.reason) });
    }
    // Respect Pinata free-tier rate limit: 5 req/sec
    if (i + concurrency < items.length) await new Promise((r) => setTimeout(r, 1100));
  }
  return results;
}
