# /vibe-audio

Design and integrate free audio for Flow blockchain games with the vibe coding aesthetic.

## Usage

- `/vibe-audio setup` — scaffold audio system (Howler.js + jsfxr) for a new game
- `/vibe-audio sfx <event>` — generate jsfxr parameters for a specific blockchain event sound
- `/vibe-audio music <state>` — find and license free music for a specific game state
- `/vibe-audio blockchain-reactive` — wire on-chain events to audio triggers
- `/vibe-audio audit` — check all audio assets have valid license registration

## Vibe Coding Aesthetic

"Vibe coding" music = programming-session ambient audio.
Target genres by game state:

| Game State | Genre | Feel |
|-----------|-------|------|
| Main menu | Lo-fi hip hop | Relaxed, warm, nostalgic |
| Dungeon / combat | Dark synthwave | Tense, focused, electronic |
| Victory / reward | Upbeat chiptune | Joyful, 8-bit, celebratory |
| Marketplace | Jazz-lo-fi | Smooth, professional |
| Dev/coding session | Classic lo-fi beats | Concentration, flow state |
| Blockchain confirms | Soft UI chimes | Satisfying, minimal |

## Free Music Sources (No Attribution)

1. **Pixabay** — Search "lo-fi" or "synthwave". CC0. Download MP3/OGG.
2. **Kenney.nl → Music Packs** — CC0. Chiptune and ambient packs. Pre-organized.
3. **OpenGameArt.org** — Filter by CC0. Large library of game music.
4. **Udio (free tier)** — AI-generate custom music. 10 songs/day free.
   - Good prompts: "lo-fi hip hop, chill, game menu, 80bpm"
   - "dark synthwave dungeon crawler, minor key, driving beat"
   - "8-bit chiptune victory fanfare, Nintendo style, upbeat"
5. **Suno (free tier)** — AI music, 50 credits/day free.

## Free SFX Sources (No Attribution)

1. **Kenney.nl → Interface Sounds** — CC0. Perfect click, pop, notification sounds.
2. **jsfxr / BFXR** — Procedural chiptune SFX. Generated = CC0. Use the presets in `procedural-sfx.ts`.
3. **ElevenLabs SFX (free tier)** — AI-generate unique sounds via text prompt. 10k chars/month free.
   - Example prompts: "satisfying coin collect chime", "digital transaction confirmation beep"

## Blockchain Event → Audio Mapping

Wire these in `audio-manager.ts`:

| On-chain Event | Sound | Feel |
|---------------|-------|------|
| NFTMinted | Ascending 3-note chime | "You got something!" |
| ListingSold | Cash register ding | "Money!" |
| RevealCompleted | Magical shimmer | "What did you get?" |
| TournamentWon | Fanfare | Celebration |
| RewardsClaimed | Soft pop | Satisfying reward |
| SystemPaused | Low alert tone | Attention-grabbing, not scary |
| TransactionConfirmed | Subtle click | Confidence, completion |

## Godot Integration

```gdscript
# In flow_client.gd, after a transaction seals:
func _on_transaction_sealed(event_type: String) -> void:
    AudioManager.play_blockchain_event(event_type)
```

## Unity Integration

```csharp
// In FlowClient.cs, after transaction sealed:
AudioManager.OnBlockchainEvent(eventType);
```

## Implementation Notes

- Use OGG format for music (better compression, browser-compatible)
- Use WAV for short SFX (lowest latency, no decode delay)
- Preload all SFX at game start; lazy-load music tracks
- Always test with headphones — cheap speakers hide mixing issues
- Keep music volume at 50% and SFX at 70% as starting mix defaults
- Add a master volume slider in the game settings — always
