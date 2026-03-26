# Godot 4 ↔ Flow Blockchain Integration Guide

**Last updated:** 2026-03-26
**Engine version:** Godot 4.6
**Flow Access API:** v1 REST (testnet + mainnet)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       Godot 4 Game                              │
│                                                                 │
│   ┌──────────────┐    ┌──────────────┐    ┌────────────────┐   │
│   │  FlowClient  │    │ FlowWallet   │    │FlowTransaction │   │
│   │  (REST API)  │    │(Auth/Signing)│    │  (Builder)     │   │
│   └──────┬───────┘    └──────┬───────┘    └───────┬────────┘   │
│          │                   │                    │             │
└──────────┼───────────────────┼────────────────────┼────────────┘
           │                   │                    │
     ┌─────┴──────┐      ┌─────┴──────┐             │
     │  Platform  │      │  Platform  │             │
     │  Native /  │      │  Web/HTML5 │             │
     │  Desktop   │      │   Export   │             │
     └─────┬──────┘      └─────┬──────┘             │
           │                   │                    │
           ▼                   ▼                    ▼
   Flow Access Node REST    FCL via           Envelope signing
   https://rest-testnet     JavaScriptBridge  (ECDSA P-256 /
   .onflow.org              (window.fcl)      secp256k1)
```

### Two Integration Paths

| Platform | Auth Method | Transaction Signing | Cadence Scripts |
|----------|-------------|---------------------|-----------------|
| Desktop / Mobile | WalletConnect GDExtension | GDExtension | REST API |
| HTML5 / Web Export | FCL via JavaScriptBridge | FCL via JavaScriptBridge | REST API |

**Key rule:** FCL is a JavaScript library. It cannot be imported as a GDScript module.
On web exports, it runs in the browser alongside Godot's HTML5 runtime.
On native builds, all Flow interaction goes through the REST API directly.

---

## Setup Instructions

### Step 1 — Add the bridge files to your project

Copy the following files into your Godot project:

```
src/flow-bridge/godot/
├── flow_client.gd       # REST API bridge (class_name FlowClient)
├── flow_transaction.gd  # Transaction builder (class_name FlowTransaction)
└── flow_wallet.gd       # Wallet authentication (class_name FlowWallet)
```

These are `RefCounted` classes — no scene tree attachment required for instantiation.
However, `HTTPRequest` nodes (used internally) must be parented to a scene node.

### Step 2 — Wire HTTPRequest into a scene node

`FlowClient._get()` and `FlowClient._post()` emit warnings in their current form
because `HTTPRequest` requires a scene tree parent. Extend `FlowClient` in your
game code to attach the `HTTPRequest` nodes properly:

```gdscript
# game/systems/flow_manager.gd
extends Node

var _client: FlowClient
var _wallet: FlowWallet
var _http_get: HTTPRequest
var _http_post: HTTPRequest

func _ready() -> void:
    _http_get = HTTPRequest.new()
    _http_post = HTTPRequest.new()
    add_child(_http_get)
    add_child(_http_post)
    _client = FlowClient.new("testnet")
    _wallet = FlowWallet.new(_client)
    _wallet.authenticated.connect(_on_wallet_authenticated)

func _on_wallet_authenticated(address: String) -> void:
    print("Wallet connected: ", address)
```

### Step 3 — Replace contract addresses

Search for placeholder addresses in the Cadence scripts embedded in `flow_client.gd`:

| Placeholder | Replace with |
|-------------|--------------|
| `0xGAMENFT_ADDRESS` | Your deployed `GameNFT` contract address |
| `0xGAMETOKEN_ADDRESS` | Your deployed `GameToken` contract address |

Use environment-specific values: emulator, testnet, mainnet addresses differ.
Consider storing them in a Godot `ConfigFile` or `ProjectSettings`:

```gdscript
const CONTRACTS := {
    "testnet": {
        "GameNFT": "0xabcdef01234567890",
        "GameToken": "0x0123456789abcdef"
    },
    "mainnet": {
        "GameNFT": "0x...",
        "GameToken": "0x..."
    }
}
```

### Step 4 (Web Export only) — Load FCL in your HTML template

For HTML5 exports, FCL must be available as `window.fcl` before the Godot runtime
calls `JavaScriptBridge.eval()`. Add this to your custom HTML template (exported
via `Project > Export > HTML5 > Custom HTML Shell`):

```html
<!-- Before the Godot engine loader script -->
<script type="module">
    import * as fcl from "https://cdn.jsdelivr.net/npm/@onflow/fcl@1.13.2/+esm";
    fcl.config()
        .put("flow.network", "testnet")
        .put("accessNode.api", "https://rest-testnet.onflow.org")
        .put("discovery.wallet", "https://fcl-discovery.onflow.org/testnet/authn");
    window.fcl = fcl;
</script>
```

Verify the FCL version matches your testnet/mainnet deployment targets.

### Step 5 (Desktop only) — Install WalletConnect GDExtension

Native desktop and mobile builds require the `flow-walletconnect` GDExtension for
wallet authentication and transaction signing. This is a community extension —
see the extension repository for installation instructions and versioning.

Without this extension, `FlowWallet.authenticate()` on non-web platforms will
emit `error("WalletConnect GDExtension not installed")`.

---

## Usage Examples

### Query an account balance

```gdscript
var client := FlowClient.new("testnet")
var account: Dictionary = await client.get_account("0xabcdef01234567")
var balance: String = account.get("balance", "0")
print("Balance: ", balance, " FLOW")
```

### Read NFT IDs from the blockchain

```gdscript
var client := FlowClient.new("testnet")
var player_address := "0xabcdef01234567"
var ids: Array = await client.get_nft_ids(player_address)
print("Player owns NFT IDs: ", ids)
```

### Execute an arbitrary Cadence script

```gdscript
const MY_SCRIPT := """
    access(all) fun main(x: Int, y: Int): Int {
        return x + y
    }
"""
var args := [
    {"type": "Int", "value": "10"},
    {"type": "Int", "value": "32"}
]
var result = await client.execute_script(MY_SCRIPT, args)
print("Result: ", result)  # 42
```

### Authenticate a wallet (web export)

```gdscript
var wallet := FlowWallet.new(client)
wallet.authenticated.connect(func(addr): print("Connected: ", addr))
wallet.error.connect(func(msg): push_error("Wallet error: " + msg))
wallet.authenticate()
# On web: opens FCL wallet discovery UI in the browser
# On desktop (with GDExtension): shows WalletConnect QR code
```

### Send a transaction and wait for confirmation

```gdscript
const COMMIT_MOVE := """
    import GameNFT from 0xGAMENFT_ADDRESS
    transaction(commitHash: UInt256) {
        prepare(signer: auth(Storage) &Account) {
            // commit the move on-chain
        }
    }
"""

var commit_hash: int = calculate_move_hash(player_move)
var tx_id: String = await client.send_transaction(
    COMMIT_MOVE,
    [{"type": "UInt256", "value": str(commit_hash)}],
    wallet.get_address(),
    wallet.sign_message
)

if tx_id.is_empty():
    push_error("Transaction failed to submit")
    return

var result: Dictionary = await client.wait_for_seal(tx_id, 30.0)
match result.get("status", ""):
    "SEALED":
        print("Move committed on-chain!")
    "EXPIRED":
        push_error("Transaction expired — network congestion?")
    "TIMEOUT":
        push_error("Seal polling timed out after 30 seconds")
```

### Display NFT metadata in UI

```gdscript
const GET_NFT_METADATA := """
    import GameNFT from 0xGAMENFT_ADDRESS
    import MetadataViews from 0x1d7e57aa55817448
    access(all) fun main(addr: Address, id: UInt64): AnyStruct {
        let col = getAccount(addr)
            .capabilities.get<&GameNFT.Collection>(GameNFT.CollectionPublicPath)
            .borrow() ?? panic("no collection")
        let nft = col.borrowGameNFT(id: id) ?? panic("no nft")
        return nft.resolveView(Type<MetadataViews.Display>())
    }
"""

func display_nft(owner: String, nft_id: int, label: Label, image: TextureRect) -> void:
    var args := [
        {"type": "Address", "value": owner},
        {"type": "UInt64", "value": str(nft_id)}
    ]
    var display = await client.execute_script(GET_NFT_METADATA, args)
    if display == null:
        return
    label.text = display.get("name", "Unknown NFT")
    # Load thumbnail from IPFS URL stored in display.thumbnail.url
    var thumb_url: String = display.get("thumbnail", {}).get("url", "")
    if thumb_url != "":
        _load_texture_from_url(thumb_url, image)
```

---

## Web Export vs Native Differences

| Feature | Web Export (HTML5) | Native (Desktop/Mobile) |
|---------|-------------------|-------------------------|
| FCL available | Yes (`window.fcl`) | No |
| Wallet auth | FCL discovery UI | WalletConnect QR (GDExtension) |
| Transaction signing | FCL `signUserMessage` | WalletConnect (GDExtension) |
| REST API calls | HTTPRequest (same) | HTTPRequest (same) |
| Cadence scripts | REST API (same) | REST API (same) |
| Polling mechanism | `JavaScriptBridge.eval()` | Native GDScript |

### Detecting the platform at runtime

```gdscript
if OS.get_name() == "Web":
    # Use FCL path
else:
    # Use WalletConnect / REST-only path
```

### Web export limitations

- FCL auth opens a popup or redirect — Godot's `JavaScriptBridge` cannot intercept
  popup windows directly; the auth result is communicated via `window.godot_flow_*`
  globals that `FlowWallet` polls for.
- Signing latency is higher on web due to the JavaScript bridge round-trip.
- Cross-origin restrictions apply: ensure your Flow access node supports CORS for
  your domain when using `fetch` from the browser context.

---

## Error Handling Patterns

### Graceful degradation when wallet is unavailable

```gdscript
func _on_play_pressed() -> void:
    if wallet.is_authenticated():
        await _start_blockchain_session()
    else:
        # Offer guest mode or prompt to connect
        _show_wallet_prompt()

func _show_wallet_prompt() -> void:
    var dialog := AcceptDialog.new()
    dialog.dialog_text = "Connect your Flow wallet to save progress on-chain.\nPlay as guest to continue without saving."
    add_child(dialog)
    dialog.popup_centered()
```

### Handling transaction failures

```gdscript
var result := await client.wait_for_seal(tx_id)
var status: String = result.get("status", "TIMEOUT")
var error_message: String = result.get("error_message", "")

if status != "SEALED":
    # Check for specific Cadence revert reasons
    if "insufficient funds" in error_message.to_lower():
        show_toast("Not enough FLOW for gas. Top up your wallet.")
    elif error_message != "":
        push_error("Transaction failed: " + error_message)
    else:
        push_error("Transaction did not seal (status: %s)" % status)
```

### Network error handling

```gdscript
var account := await client.get_account(address)
if account.is_empty():
    # REST call returned empty dict (network error or address not found)
    push_warning("Could not fetch account for address: " + address)
    # Fall back to cached data if available
    account = _load_cached_account(address)
```

---

## Performance Guidance

### Rate limits

The Flow testnet Access Node enforces **50 requests/second** per IP.
Mainnet limits are higher but not documented; treat as 100 req/sec to be safe.

### Caching strategy

Avoid polling on-chain state every frame. Cache aggressively:

```gdscript
# Cache NFT data for 60 seconds
var _nft_cache: Dictionary = {}
var _nft_cache_time: Dictionary = {}
const CACHE_TTL_SEC := 60.0

func get_nft_ids_cached(address: String) -> Array:
    var now := Time.get_ticks_msec() / 1000.0
    if _nft_cache.has(address) and (now - _nft_cache_time[address]) < CACHE_TTL_SEC:
        return _nft_cache[address]
    var ids := await client.get_nft_ids(address)
    _nft_cache[address] = ids
    _nft_cache_time[address] = now
    return ids
```

### Batch reads with Cadence scripts

Instead of N separate REST calls for N NFTs, write one Cadence script that returns
all N items in a single response:

```cadence
access(all) fun main(addr: Address, ids: [UInt64]): [{String: AnyStruct}] {
    // fetch all NFT metadata in one script execution
}
```

### Avoid blocking the main thread

All `await` calls in `FlowClient` are non-blocking (coroutines). Ensure you always
`await` them so the game loop is not stalled:

```gdscript
# Correct: non-blocking
var ids: Array = await client.get_nft_ids(address)

# Wrong: will hang the engine if called without await in a non-async context
var ids: Array = client.get_nft_ids(address)  # returns a Signal, not an Array
```

---

## Testing with the Flow Emulator

For local development, use the Flow emulator instead of testnet:

```gdscript
var client := FlowClient.new("emulator")
# Connects to http://localhost:8888
```

Start the emulator and deploy contracts before running the game:

```bash
flow emulator start
flow project deploy --network=emulator
```

### Mock the REST API for unit tests

For Godot unit tests (using GUT or similar), inject a mock `FlowClient` that
returns deterministic data without network calls:

```gdscript
class MockFlowClient extends FlowClient:
    func get_nft_ids(_address: String) -> Array:
        return [1, 2, 3]  # predictable test data
    func get_token_balance(_address: String) -> float:
        return 100.0
```

---

## Type Conversion Reference

Flow Cadence types map to Godot types as follows:

| Cadence Type | Godot Type | Notes |
|--------------|------------|-------|
| `UInt64` | `int` | Use `int(str_value)` |
| `UInt256` | `int` | Godot int is 64-bit; use `String` for values > 2^63 |
| `UFix64` | `float` | `float(str_value)` — 8 decimal places |
| `Fix64` | `float` | Signed fixed-point |
| `Address` | `String` | Keep as hex string with `0x` prefix |
| `String` | `String` | Direct mapping |
| `Bool` | `bool` | `true`/`false` |
| `[T]` | `Array` | JSON array from script response |
| `{K: V}` | `Dictionary` | JSON object from script response |
| `Optional<T>` | `Variant` | May be `null` — always null-check |

All values from Cadence scripts arrive as JSON strings in the Flow REST response.
Parse them after base64-decoding the `value` field.

---

## Related Files

- `src/flow-bridge/godot/flow_client.gd` — REST API client implementation
- `src/flow-bridge/godot/flow_transaction.gd` — Transaction construction and signing
- `src/flow-bridge/godot/flow_wallet.gd` — Wallet authentication layer
- `.claude/agents/flow-godot-bridge.md` — AI agent for this integration domain
- `docs/flow-reference/fcl-api.md` — FCL API reference (web export context)
- `docs/flow/deployment-guide.md` — Deploying contracts to testnet/mainnet
- `cadence/contracts/` — Deployed Cadence smart contracts
