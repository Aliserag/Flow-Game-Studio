# /flow-ai-npc

Generate provably fair NPC dialogue systems using Claude API with on-chain commitment.

## Usage

- `/flow-ai-npc setup --npc "Blacksmith Thorin" --personality "gruff, respects skill"` — scaffold NPC system
- `/flow-ai-npc test --npc-id blacksmith --message "Got any swords?"` — test dialogue generation
- `/flow-ai-npc commit-schema` — design on-chain commitment structure for a new NPC type

## Why On-Chain Commitment

Without commitment: game could regenerate responses until getting the "best" one for the studio.
With commitment: response is locked in before player sees it. Auditable and trustless.

This matters for:
- Quest givers that offer random rewards in dialogue
- Shopkeepers with "fair" pricing (commitment proves price wasn't changed after seeing player's wallet)
- Boss taunts that include player-specific information (proves it was generated, not hand-crafted)

## Prompt Engineering for Game NPCs

Best practices for Flow game NPCs:
- Include player's NFT/achievement data in the system prompt — NPC reacts to what player owns
- Include current game state (season, dungeon level) for contextual awareness
- Use character voice constraints — max 2-3 sentences to keep responses punchy
- Add "do not break character" instruction to prevent the NPC from explaining game mechanics out of character
- Temperature: 0.8 for personality variety, 0.3 for consistent quest-giving NPCs

## Procedural Content Generation

For VRF-seeded content (dungeon layouts, loot descriptions):
1. Use RandomVRF to generate a seed
2. Pass seed + game state as context to Claude API
3. Commit hash of generated content on-chain
4. Claude generates consistent content from the same seed
