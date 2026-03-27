// generate-sfx.ts
// CLI tool to batch-generate SFX WAV files using jsfxr parameters.
// Saves generated sounds to assets/audio/sfx/ for use in-game.
//
// Usage:
//   npx ts-node tools/audio/generate-sfx.ts
//   npx ts-node tools/audio/generate-sfx.ts --preset nft_mint --output assets/audio/sfx/

import { writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { SFX_PRESETS } from "../../src/audio/procedural-sfx";

// jsfxr WAV generation (Node.js implementation)
// Based on: https://github.com/chr15m/jsfxr
function generateWAV(params: number[]): Buffer {
  // jsfxr parameters to WAV conversion
  // In production, use: npm install jsfxr
  // This is a placeholder that generates a minimal valid WAV file
  const sampleRate = 44100;
  const numChannels = 1;
  const bitsPerSample = 16;
  const numSamples = sampleRate; // 1 second

  const dataSize = numSamples * numChannels * (bitsPerSample / 8);
  const header = Buffer.alloc(44);

  header.write("RIFF", 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);          // PCM chunk size
  header.writeUInt16LE(1, 20);           // PCM format
  header.writeUInt16LE(numChannels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(sampleRate * numChannels * (bitsPerSample / 8), 28);
  header.writeUInt16LE(numChannels * (bitsPerSample / 8), 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write("data", 36);
  header.writeUInt32LE(dataSize, 40);

  // Generate simple tone based on first param (waveType)
  const audioData = Buffer.alloc(dataSize);
  const freq = 440 + (params[5] ?? 0.5) * 880; // frequency from pitch param
  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    const envelope = Math.max(0, 1 - t / 0.3); // simple decay
    const sample = Math.sin(2 * Math.PI * freq * t) * envelope * 32767;
    audioData.writeInt16LE(Math.round(sample), i * 2);
  }

  return Buffer.concat([header, audioData]);
}

const OUTPUT_DIR = process.argv.includes("--output")
  ? process.argv[process.argv.indexOf("--output") + 1]
  : "assets/audio/sfx";

const presetFilter = process.argv.includes("--preset")
  ? process.argv[process.argv.indexOf("--preset") + 1]
  : null;

mkdirSync(OUTPUT_DIR, { recursive: true });

const presetsToGenerate = presetFilter
  ? { [presetFilter]: SFX_PRESETS[presetFilter] }
  : SFX_PRESETS;

for (const [name, params] of Object.entries(presetsToGenerate)) {
  if (!params) {
    console.warn(`Unknown preset: ${name}`);
    continue;
  }
  const wavData = generateWAV(params);
  const outputPath = join(OUTPUT_DIR, `${name}.wav`);
  writeFileSync(outputPath, wavData);
  console.log(`Generated: ${outputPath} (${wavData.length} bytes)`);
}

console.log(`\nDone. ${Object.keys(presetsToGenerate).length} SFX generated in ${OUTPUT_DIR}/`);
console.log("Note: Install jsfxr (npm install jsfxr) for high-quality procedural audio.");
