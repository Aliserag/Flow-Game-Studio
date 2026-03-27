// audio-manager.ts
// Howler.js-based audio manager with Flow blockchain event bindings.
// Plays reactive sounds when on-chain events are detected by the indexer.

import { Howl, Howler } from "howler";

export interface AudioConfig {
  masterVolume: number;      // 0.0 - 1.0
  musicVolume: number;
  sfxVolume: number;
  muted: boolean;
}

// Blockchain event → sound effect mapping
const BLOCKCHAIN_SOUNDS: Record<string, string> = {
  "GameNFT.NFTMinted":        "sfx/nft_mint.wav",
  "Marketplace.ListingSold":  "sfx/marketplace_sale.wav",
  "RandomVRF.RevealCompleted":"sfx/vrf_reveal.wav",
  "Tournament.PrizeDistributed": "sfx/tournament_win.wav",
  "StakingPool.RewardsClaimed": "sfx/reward_claim.wav",
  "EmergencyPause.SystemPaused": "sfx/system_alert.wav",
};

// Game state → ambient music mapping (lo-fi / vibe coding aesthetic)
const AMBIENT_TRACKS: Record<string, string> = {
  menu:        "music/menu_lofi.ogg",      // Chill lo-fi hip hop
  dungeon:     "music/dungeon_dark.ogg",   // Tense synthwave
  victory:     "music/victory_upbeat.ogg", // Upbeat chiptune
  marketplace: "music/market_ambient.ogg", // Relaxed jazz-lo-fi
  coding:      "music/vibe_coding.ogg",    // Classic lo-fi for dev sessions
};

const sounds = new Map<string, Howl>();
let currentTrack: Howl | null = null;
let currentTrackName: string | null = null;

function getOrLoadSound(path: string): Howl {
  if (!sounds.has(path)) {
    sounds.set(path, new Howl({
      src: [path],
      preload: true,
      volume: Howler.volume(),
    }));
  }
  return sounds.get(path)!;
}

export const AudioManager = {
  init(config: Partial<AudioConfig> = {}): void {
    Howler.volume(config.masterVolume ?? 0.7);
    if (config.muted) Howler.mute(true);
  },

  // Play a one-shot sound effect
  playSFX(name: string): void {
    const path = `assets/audio/${name}`;
    getOrLoadSound(path).play();
  },

  // React to a blockchain event type
  onBlockchainEvent(eventType: string): void {
    const soundFile = Object.entries(BLOCKCHAIN_SOUNDS).find(([key]) =>
      eventType.includes(key)
    )?.[1];
    if (soundFile) this.playSFX(soundFile);
  },

  // Transition ambient music based on game state
  setGameState(state: keyof typeof AMBIENT_TRACKS): void {
    const trackPath = AMBIENT_TRACKS[state];
    if (!trackPath || currentTrackName === trackPath) return;

    if (currentTrack) {
      currentTrack.fade(currentTrack.volume(), 0, 1000);
      setTimeout(() => currentTrack?.stop(), 1000);
    }

    currentTrackName = trackPath;
    const newTrack = getOrLoadSound(`assets/audio/${trackPath}`);
    newTrack.loop(true);
    newTrack.volume(0);
    newTrack.play();
    newTrack.fade(0, 0.5, 1500);
    currentTrack = newTrack;
  },

  setMasterVolume(v: number): void { Howler.volume(Math.max(0, Math.min(1, v))); },
  mute(): void { Howler.mute(true); },
  unmute(): void { Howler.mute(false); },
};
