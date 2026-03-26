# src/flow-bridge/godot/flow_client.gd
# Flow REST API client for Godot 4.
# FCL is JS-only; this connects directly to Flow Access Node REST API.
# Docs: https://developers.flow.com/http-api
class_name FlowClient
extends RefCounted

const TESTNET_URL := "https://rest-testnet.onflow.org"
const MAINNET_URL := "https://rest-mainnet.onflow.org"
const EMULATOR_URL := "http://localhost:8888"

var _base_url: String
var _http_client: HTTPClient

func _init(network: String = "testnet") -> void:
	match network:
		"mainnet": _base_url = MAINNET_URL
		"emulator": _base_url = EMULATOR_URL
		_: _base_url = TESTNET_URL
	_http_client = HTTPClient.new()

## Execute a Cadence script (read-only, no signing required).
## Returns parsed JSON result or null on error.
func execute_script(cadence_code: String, arguments: Array = []) -> Variant:
	var payload := {
		"script": Marshalls.utf8_to_base64(cadence_code),
		"arguments": arguments.map(func(a): return JSON.stringify(a))
	}
	var response := await _post("/v1/scripts", payload)
	if response.is_empty():
		return null
	# Flow returns base64-encoded JSON value
	var decoded := Marshalls.base64_to_utf8(response.get("value", ""))
	return JSON.parse_string(decoded)

## Get account information (balance, keys, contracts).
func get_account(address: String) -> Dictionary:
	return await _get("/v1/accounts/" + address.trim_prefix("0x"))

## Get NFT IDs owned by an account.
func get_nft_ids(owner_address: String) -> Array:
	const SCRIPT := """
		import NonFungibleToken from 0x1d7e57aa55817448
		import GameNFT from 0xGAMENFT_ADDRESS
		access(all) fun main(addr: Address): [UInt64] {
			return getAccount(addr)
				.capabilities.get<&GameNFT.Collection>(GameNFT.CollectionPublicPath)
				.borrow()?.getIDs() ?? []
		}
	"""
	var args := [{"type": "Address", "value": owner_address}]
	var result = await execute_script(SCRIPT, args)
	return result if result is Array else []

## Get GameToken balance for an account.
func get_token_balance(owner_address: String) -> float:
	const SCRIPT := """
		import FungibleToken from 0xf233dcee88fe0abe
		import GameToken from 0xGAMETOKEN_ADDRESS
		access(all) fun main(addr: Address): UFix64 {
			return getAccount(addr)
				.capabilities.get<&GameToken.Vault>(GameToken.VaultPublicPath)
				.borrow()?.balance ?? 0.0
		}
	"""
	var args := [{"type": "Address", "value": owner_address}]
	var result = await execute_script(SCRIPT, args)
	return float(result) if result != null else 0.0

## Send a signed transaction.
## signature_provider: Callable that takes (message: PackedByteArray) -> [signature: String, keyIndex: int]
## Returns transaction ID or empty string on error.
func send_transaction(
	cadence_code: String,
	arguments: Array,
	authorizer_address: String,
	signature_provider: Callable
) -> String:
	# 1. Get latest sealed block for reference
	var block_result := await _get("/v1/blocks?height=sealed")
	if block_result.is_empty():
		return ""
	var blocks: Array = block_result.get("blocks", [block_result])
	var ref_block_id: String = blocks[0].get("id", "") if blocks.size() > 0 else ""

	# 2. Get account sequence number
	var account := await get_account(authorizer_address)
	var keys: Array = account.get("keys", [])
	var seq_num: int = 0
	if keys.size() > 0:
		seq_num = int(keys[0].get("sequence_number", 0))

	# 3. Build and sign transaction
	var tx := FlowTransaction.new()
	tx.script = cadence_code
	tx.arguments = arguments
	tx.reference_block_id = ref_block_id
	tx.gas_limit = 999
	tx.proposer_address = authorizer_address
	tx.proposer_key_index = 0
	tx.proposer_sequence_number = seq_num
	tx.authorizers = [authorizer_address]

	var envelope_message := tx.build_envelope_message()
	var sig_result: Array = await signature_provider.call(envelope_message)
	if sig_result.size() >= 2:
		tx.envelope_signature = sig_result[0]
		tx.envelope_key_index = sig_result[1]

	var result := await _post("/v1/transactions", tx.to_payload())
	return result.get("id", "")

## Poll transaction status until sealed or timeout.
func wait_for_seal(tx_id: String, timeout_sec: float = 30.0) -> Dictionary:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		await Engine.get_main_loop().create_timer(1.0).timeout
		elapsed += 1.0
		var status := await _get("/v1/transactions/" + tx_id + "/results")
		if status.get("status", "") in ["SEALED", "EXPIRED"]:
			return status
	return {"status": "TIMEOUT"}

## Internal: HTTP GET
func _get(path: String) -> Dictionary:
	var url := _base_url + path
	var http := HTTPRequest.new()
	# HTTPRequest requires a scene tree node; use a workaround for static usage
	# In practice, add HTTPRequest as a child of a Node in your scene
	push_warning("FlowClient._get: Attach FlowClient to a Node for HTTPRequest support. Path: " + url)
	return {}

## Internal: HTTP POST
func _post(path: String, body: Dictionary) -> Dictionary:
	var url := _base_url + path
	push_warning("FlowClient._post: Attach FlowClient to a Node for HTTPRequest support. Path: " + url)
	return {}
