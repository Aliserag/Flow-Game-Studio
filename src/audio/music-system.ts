// music-system.ts
// State-based ambient music system for Flow blockchain games.
// Manages crossfading between tracks based on game state transitions.
// Integrates with blockchain event stream for reactive music changes.

export type GameMusicState =
  | "menu"
  | "dungeon"
  | "victory"
  | "marketplace"
  | "coding"
  | "idle";

export interface MusicTrack {
  path: string;
  loop: boolean;
  fadeInMs: number;
  fadeOutMs: number;
  volume: number;  // 0.0 - 1.0
}

export const MUSIC_TRACKS: Record<GameMusicState, MusicTrack> = {
  menu: {
    path: "assets/audio/music/menu_lofi.ogg",
    loop: true, fadeInMs: 1500, fadeOutMs: 1000, volume: 0.5,
  },
  dungeon: {
    path: "assets/audio/music/dungeon_dark.ogg",
    loop: true, fadeInMs: 800, fadeOutMs: 600, volume: 0.6,
  },
  victory: {
    path: "assets/audio/music/victory_upbeat.ogg",
    loop: false, fadeInMs: 200, fadeOutMs: 2000, volume: 0.7,
  },
  marketplace: {
    path: "assets/audio/music/market_ambient.ogg",
    loop: true, fadeInMs: 2000, fadeOutMs: 1500, volume: 0.4,
  },
  coding: {
    path: "assets/audio/music/vibe_coding.ogg",
    loop: true, fadeInMs: 3000, fadeOutMs: 2000, volume: 0.35,
  },
  idle: {
    path: "",
    loop: false, fadeInMs: 0, fadeOutMs: 1000, volume: 0,
  },
};

// Blockchain events that trigger automatic state transitions
export const EVENT_TO_MUSIC_STATE: Record<string, GameMusicState> = {
  "Tournament.PrizeDistributed": "victory",
  "Marketplace.ListingCreated":  "marketplace",
  "Marketplace.ListingSold":     "marketplace",
};

export class MusicSystem {
  private currentState: GameMusicState = "idle";
  private previousState: GameMusicState = "idle";

  constructor(private readonly onStateChange?: (from: GameMusicState, to: GameMusicState) => void) {}

  transitionTo(newState: GameMusicState): void {
    if (newState === this.currentState) return;
    this.previousState = this.currentState;
    this.currentState = newState;
    this.onStateChange?.(this.previousState, this.currentState);
  }

  onBlockchainEvent(eventType: string): void {
    for (const [pattern, state] of Object.entries(EVENT_TO_MUSIC_STATE)) {
      if (eventType.includes(pattern)) {
        this.transitionTo(state);
        return;
      }
    }
  }

  getCurrentTrack(): MusicTrack {
    return MUSIC_TRACKS[this.currentState];
  }

  getState(): GameMusicState {
    return this.currentState;
  }

  getPreviousState(): GameMusicState {
    return this.previousState;
  }
}
