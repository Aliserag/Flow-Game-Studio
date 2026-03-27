# Unity ↔ Flow Integration Guide

This guide explains how to connect a Unity game to the Flow blockchain using the
`FlowBridge` C# library (`src/flow-bridge/unity/`).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Unity Game                             │
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────┐  │
│  │  FlowClient  │   │  FlowWallet  │   │  FlowNFTDisplay    │  │
│  │  (REST API)  │   │  (Auth/Sign) │   │  (UI Component)    │  │
│  └──────┬───────┘   └──────┬───────┘   └────────┬───────────┘  │
│         │                  │                     │              │
└─────────┼──────────────────┼─────────────────────┼─────────────┘
          │                  │                     │
          │      Standalone / Mobile               │
          │      ──────────────────                │
          ▼                  ▼                     ▼
  Flow REST API        WalletConnect          Flow REST API
  Access Node          (SDK plugin)           Access Node
  (UnityWebRequest)                           (UnityWebRequest)

          │                  │
          │      WebGL Export                      │
          │      ──────────────                    │
          ▼                  ▼                     ▼
  Flow REST API    FCL (JavaScript)        Flow REST API
  Access Node      Application.ExternalEval Access Node
```

### Two connectivity paths

| Path | Platforms | How |
|------|-----------|-----|
| REST API | All platforms | `UnityWebRequest` → Flow Access Node `/v1/` endpoints |
| FCL (wallet auth/signing) | WebGL only | `Application.ExternalEval` → `window.fcl` in browser |

FCL is a JavaScript library and cannot be imported as a C# package. On non-WebGL
platforms, wallet authentication and signing require the WalletConnect Unity SDK
(a separate third-party plugin).

## Prerequisites

### Unity version

Unity 2022.2 or later is required for the `await Task.Yield()` pattern used with
`UnityWebRequest`. Unity 2021 LTS works with minor modifications (avoid C# 8 switch
expressions in `BaseUrl`).

### Newtonsoft.Json

`FlowClient.cs` and `FlowNFTDisplay.cs` depend on `Newtonsoft.Json` for JSON
serialization. Install it via the Unity Package Manager:

1. Open **Window > Package Manager**
2. Click **+** > **Add package by name**
3. Enter `com.unity.nuget.newtonsoft-json`
4. Click **Add**

Alternatively, add to `Packages/manifest.json`:

```json
{
  "dependencies": {
    "com.unity.nuget.newtonsoft-json": "3.2.1"
  }
}
```

### TextMeshPro (for FlowNFTDisplay)

`FlowNFTDisplay.cs` uses `TextMeshProUGUI`. Install TMP via **Window > TextMeshPro >
Import TMP Essential Resources** if it is not already in your project.

## Setup

### 1. Copy scripts into Unity project

Copy the three files into your Unity project's `Assets` folder (any subfolder works):

```
Assets/
  FlowBridge/
    FlowClient.cs
    FlowWallet.cs
    FlowNFTDisplay.cs
```

### 2. Add FlowClient to a GameObject

Create an empty GameObject named `FlowManager` in your scene. Add the `FlowClient`
component. Select the target network in the Inspector:

- **Emulator** — `http://localhost:8888` (local Flow Emulator)
- **Testnet** — `https://rest-testnet.onflow.org` (default)
- **Mainnet** — `https://rest-mainnet.onflow.org`

### 3. Add FlowWallet to the same GameObject

Add the `FlowWallet` component to `FlowManager`. Call `Initialize(flowClient)` from
your game's start-up script:

```csharp
void Start()
{
    var client = GetComponent<FlowClient>();
    var wallet = GetComponent<FlowWallet>();
    wallet.Initialize(client);
    wallet.OnAuthenticated += addr => Debug.Log($"Authenticated: {addr}");
    wallet.OnError += msg => Debug.LogError($"Wallet error: {msg}");
}
```

### 4. WebGL HTML template (WebGL builds only)

Add the FCL script tag to your WebGL HTML template before the Unity loader script:

```html
<!-- index.html or WebGL template -->
<script src="https://cdn.jsdelivr.net/npm/@onflow/fcl/dist/fcl.umd.js"></script>
<script>
  window.fcl.config({
    "flow.network": "testnet",
    "accessNode.api": "https://rest-testnet.onflow.org",
    "discovery.wallet": "https://fcl-discovery.onflow.org/testnet/authn"
  });
</script>
```

The template lives at `Assets/WebGLTemplates/Default/index.html`. Copy the built-in
`Default` template and modify it if you have not already.

## Usage Examples

### Authenticate the player

```csharp
public class LoginScreen : MonoBehaviour
{
    [SerializeField] private FlowWallet _wallet;
    [SerializeField] private TMPro.TextMeshProUGUI _addressLabel;

    void Start()
    {
        _wallet.OnAuthenticated += addr =>
        {
            _addressLabel.text = $"Connected: {addr}";
            LoadPlayerData(addr);
        };
    }

    public void OnLoginButtonClicked()
    {
        _wallet.Authenticate();
    }

    private async void LoadPlayerData(string address)
    {
        var client = GetComponent<FlowClient>();
        var balance = await client.GetTokenBalance(address);
        Debug.Log($"Token balance: {balance}");
    }
}
```

### Read NFTs owned by the player

```csharp
public class InventoryScreen : MonoBehaviour
{
    [SerializeField] private FlowClient _client;
    [SerializeField] private FlowNFTDisplay _nftDisplayPrefab;
    [SerializeField] private Transform _gridContainer;

    public async void RefreshInventory(string playerAddress)
    {
        // Clear existing display
        foreach (Transform child in _gridContainer)
            Destroy(child.gameObject);

        // Fetch NFT IDs from chain
        var ids = await _client.GetNFTIds(playerAddress);
        Debug.Log($"Found {ids.Count} NFTs for {playerAddress}");

        // Display each NFT
        foreach (var id in ids)
        {
            var display = Instantiate(_nftDisplayPrefab, _gridContainer);
            await display.DisplayNFT(playerAddress, id);
        }
    }
}
```

### Send a transaction (commit a game move)

```csharp
public class GameBoard : MonoBehaviour
{
    [SerializeField] private FlowClient _client;
    [SerializeField] private FlowWallet _wallet;

    private const string COMMIT_MOVE_CADENCE = @"
        import GameContract from 0xGAMECONTRACT_ADDRESS
        transaction(moveHash: String) {
            prepare(signer: auth(BorrowValue) &Account) {
                GameContract.commitMove(player: signer.address, hash: moveHash)
            }
        }
    ";

    public async void CommitMove(string moveHash)
    {
        if (!_wallet.IsAuthenticated)
        {
            Debug.LogError("Player not authenticated");
            return;
        }

        var args = new object[] { new { type = "String", value = moveHash } };

        var txId = await _client.SendTransaction(
            COMMIT_MOVE_CADENCE,
            args,
            _wallet.Address,
            _wallet.SignMessage
        );

        if (string.IsNullOrEmpty(txId))
        {
            Debug.LogError("Transaction submission failed");
            return;
        }

        Debug.Log($"Transaction submitted: {txId}");

        var result = await _client.WaitForSeal(txId, timeoutSeconds: 30f);
        var status = result?["status"]?.ToString();

        if (status == "SEALED")
            Debug.Log("Move committed on-chain");
        else
            Debug.LogWarning($"Transaction ended with status: {status}");
    }
}
```

### Execute a read-only Cadence script

```csharp
public async Task<int> GetPlayerLevel(string address)
{
    const string script = @"
        import GameContract from 0xGAMECONTRACT_ADDRESS
        access(all) fun main(addr: Address): Int {
            return GameContract.getPlayerLevel(addr)
        }
    ";
    var args = new[] { new { type = "Address", value = address } };
    var result = await _client.ExecuteScript(script, args);
    return result?.Value<int>() ?? 0;
}
```

## WebGL vs Standalone Differences

| Feature | WebGL | Standalone / Mobile |
|---------|-------|---------------------|
| REST API reads | `UnityWebRequest` | `UnityWebRequest` |
| Wallet authentication | FCL via `ExternalEval` | WalletConnect SDK (required) |
| Transaction signing | FCL via `ExternalEval` | WalletConnect SDK (required) |
| CORS restrictions | None (server-side) | None |
| FCL script tag required | Yes | No |
| `Application.ExternalEval` | Works | No-op (silently ignored) |

On standalone builds, `FlowWallet.Authenticate()` logs a warning and fires
`OnError` because WalletConnect is not bundled. To add WalletConnect:
1. Import the [WalletConnect Unity SDK](https://github.com/WalletConnect/WalletConnectUnity)
2. Replace `AuthenticateWalletConnect()` with the SDK's pairing flow
3. Replace `SignMessage` with the SDK's `personal_sign` request

## Error Handling

`FlowClient` logs errors via `Debug.LogError` and returns `null` on failure.
Always null-check results before use:

```csharp
var ids = await client.GetNFTIds(address);
if (ids == null || ids.Count == 0)
{
    ShowEmptyInventoryState();
    return;
}
```

For transactions, check `WaitForSeal` status:

```csharp
var result = await client.WaitForSeal(txId);
switch (result?["status"]?.ToString())
{
    case "SEALED":  HandleSuccess(); break;
    case "EXPIRED": HandleExpired(); break;
    case "TIMEOUT": HandleTimeout(); break;
    default:        HandleUnknown(); break;
}
```

Error codes in `result["errorMessage"]` are set when a transaction reverts on-chain.

## Performance and Caching

On-chain reads are network calls and should not run every frame. Cache results in
`ScriptableObject` or `PlayerPrefs`:

```csharp
// Cache NFT IDs per address in a ScriptableObject
[CreateAssetMenu]
public class NFTCache : ScriptableObject
{
    private Dictionary<string, (List<ulong> ids, DateTime fetchedAt)> _cache = new();

    public bool TryGet(string address, out List<ulong> ids)
    {
        if (_cache.TryGetValue(address, out var entry)
            && DateTime.UtcNow - entry.fetchedAt < TimeSpan.FromMinutes(2))
        {
            ids = entry.ids;
            return true;
        }
        ids = null;
        return false;
    }

    public void Set(string address, List<ulong> ids)
        => _cache[address] = (ids, DateTime.UtcNow);
}
```

Guidelines:
- Fetch balances/NFT lists at login and on explicit refresh, not continuously
- Use a TTL of 30–120 seconds for balance data
- Transactions invalidate the cache immediately for optimistic UI updates
- Avoid concurrent duplicate requests for the same address

## Flow → C# Type Conversion Reference

| Flow / Cadence type | C# type | Notes |
|---------------------|---------|-------|
| `UInt64` | `ulong` | NFT IDs, amounts |
| `UFix64` | `decimal` | Token balances (divide by 1e8 for display) |
| `String` | `string` | Names, hashes |
| `Address` | `string` | Keep `0x` prefix for display; strip for REST calls |
| `Bool` | `bool` | |
| `Int` / `Int32` | `int` | |
| `[UInt64]` | `List<ulong>` | Arrays |
| `{String: AnyStruct}` | `JObject` | Dictionaries via Newtonsoft |
| `Optional<T>` (nil) | `null` | Always null-check `JToken` results |

### UFix64 note

Flow stores token balances as `UFix64` (fixed-point, 8 decimal places). The REST
API returns them as strings like `"12.34000000"`. Parse with `decimal.Parse` or
`JToken.Value<decimal>()`.

## Replacing Placeholder Addresses

The Cadence scripts in `FlowClient.cs` and `FlowNFTDisplay.cs` contain placeholder
contract addresses (`0xGAMENFT_ADDRESS`, `0xGAMETOKEN_ADDRESS`). Replace these with
actual deployed addresses before use:

```csharp
// In FlowClient.cs (or a configuration ScriptableObject)
private const string GameNFTAddress  = "0xabcdef1234567890"; // testnet address
private const string GameTokenAddress = "0x1234567890abcdef"; // testnet address

// Use string replacement when building scripts:
var script = GET_NFT_SCRIPT
    .Replace("0xGAMENFT_ADDRESS", GameNFTAddress)
    .Replace("0xGAMETOKEN_ADDRESS", GameTokenAddress);
```

See `flow.json` for the canonical address mapping.

## See Also

- `src/flow-bridge/godot/` — equivalent GDScript bridge for Godot 4
- `docs/flow/engine-integration/godot-flow-bridge.md` — Godot integration guide
- `docs/flow-reference/fcl-api.md` — FCL API reference (for WebGL context)
- `docs/flow-reference/VERSION.md` — Cadence/Flow version pins
- Flow REST API: https://developers.flow.com/http-api
- WalletConnect Unity SDK: https://github.com/WalletConnect/WalletConnectUnity
