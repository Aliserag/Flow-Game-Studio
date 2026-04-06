// procedural-sfx.ts
// Generates retro/chiptune sound effects procedurally using jsfxr parameters.
// No external audio files needed — generates WAV data in the browser.
// Perfect for blockchain transaction feedback (unique sound per event type).

// jsfxr parameter format: array of 24 numbers defining the synthesizer state
// See: https://github.com/chr15m/jsfxr for parameter reference

type SFXParams = number[];

// Preset parameters for common game events
// Generated using the jsfxr web tool (sfxr.me) — all CC0

export const SFX_PRESETS: Record<string, SFXParams> = {
  // NFT Mint — ascending coin collect
  nft_mint: [0,0,0.3,0.5,0.5,0.7,0,0.2,0,0,0.5,0.5,0,0,0,0,0,0.5,1,0.1,0,0.5,0,0.5],

  // Transaction confirmed — satisfying click/pop
  tx_confirm: [3,0,0.15,0,0.1,0.5,0,0,0,0,0,0,0,0,0,0,0,0,1,0.1,0,0,0,0.5],

  // Marketplace sale — cash register
  marketplace_sale: [0,0,0.25,0.15,0.3,0.55,0,0.15,0,0,0.4,0.4,0,0,0,0,0,0.6,0.8,0.1,0,0.4,0,0.5],

  // VRF reveal — magical shimmer
  vrf_reveal: [1,0,0.1,0.5,0.5,0.6,0,0,0,0,0.3,0.6,0,0,0,0.1,0,0.5,1,0.1,0,0,0,0.5],

  // Error / failed tx — low buzz
  error: [3,0,0.2,0,0.15,0.2,0,0,0,0,0,0,0,0,0.5,0.2,0,0,1,0.1,0,0,0,0.5],

  // Level up / achievement — fanfare
  achievement: [0,0,0.3,0.5,0.6,0.8,0,0.3,0,0,0.6,0.5,0,0,0,0,0,0.8,1,0.1,0,0.6,0,0.5],

  // Reward claimed — happy jingle
  reward: [0,0,0.25,0.4,0.5,0.7,0,0.25,0,0,0.5,0.5,0,0,0,0,0,0.5,1,0.1,0,0.5,0,0.5],
};

export function generateSFXDataURL(params: SFXParams): string {
  // This function requires jsfxr to be loaded.
  // In browser: import jsfxr from 'jsfxr'
  // Returns a data URL for the generated WAV file
  // Usage: new Audio(generateSFXDataURL(SFX_PRESETS.nft_mint)).play()
  if (typeof (window as any).jsfxr !== "undefined") {
    return (window as any).jsfxr(params);
  }
  console.warn("jsfxr not loaded — add <script src='jsfxr.js'></script>");
  return "";
}

export function playSFX(presetName: keyof typeof SFX_PRESETS): void {
  const params = SFX_PRESETS[presetName];
  if (!params) return;
  const dataURL = generateSFXDataURL(params);
  if (dataURL) new Audio(dataURL).play();
}
