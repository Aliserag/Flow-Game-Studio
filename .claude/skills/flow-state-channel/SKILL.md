# /flow-state-channel

Design and implement state channel patterns for high-frequency Flow games.

## Usage

- `/flow-state-channel open --stake 100 --opponent 0xabc` — generate channel open transaction
- `/flow-state-channel close --channel-id 5 --state latest-state.json` — close with final state
- `/flow-state-channel dispute --channel-id 5 --state newer-state.json` — file dispute
- `/flow-state-channel design --game chess` — design channel state structure for a specific game

## When to Use State Channels

| Use State Channels | Use Direct Transactions |
|-------------------|------------------------|
| Real-time PvP (chess, card battle, racing) | Turn-based games with >30s per move |
| >10 moves per minute | <5 moves per minute |
| Both players online simultaneously | Async play acceptable |
| Game has clear winner/loser with token stake | No stake involved |

## State Channel Lifecycle

```
open_channel.cdc          game (off-chain signing)           close_channel.cdc
[A and B deposit] → [sign state updates: seqNum++] → [submit latest mutually-signed state]
                                                           ↓
                                               250-block dispute window
                                                           ↓
                                              settle_channel.cdc (anyone can call)
```

## Off-chain Signing Security

- NEVER reveal your private key to the channel opponent
- ALWAYS verify opponent's signature before signing a new state
- KEEP the full history of signed states (in case you need to dispute)
- NEVER sign a state that gives the opponent more than they should have
- seqNum must strictly increase — reject any state with seqNum ≤ current
