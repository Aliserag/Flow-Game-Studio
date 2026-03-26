# src/flow-bridge/godot/flow_transaction.gd
# Represents a Flow transaction for construction and signing.
# Flow transaction format: https://developers.flow.com/concepts/start-here/transaction-signing
class_name FlowTransaction
extends RefCounted

var script: String = ""
var arguments: Array = []
var reference_block_id: String = ""
var gas_limit: int = 999
var proposer_address: String = ""
var proposer_key_index: int = 0
var proposer_sequence_number: int = 0
var authorizers: Array = []
var envelope_signature: String = ""
var envelope_key_index: int = 0

## Build the envelope message bytes for signing.
## The envelope is the RLP-encoded transaction without the envelope sig.
func build_envelope_message() -> PackedByteArray:
	# Simplified: in production, RLP-encode the transaction per Flow spec
	# See: https://developers.flow.com/concepts/start-here/transaction-signing#signing-envelope
	var message := "%s%s%s%d%d" % [
		script.sha256_text(),
		reference_block_id,
		proposer_address,
		proposer_key_index,
		proposer_sequence_number
	]
	return message.to_utf8_buffer()

## Build the REST API payload for /v1/transactions
func to_payload() -> Dictionary:
	return {
		"script": Marshalls.utf8_to_base64(script),
		"arguments": arguments.map(func(a): return JSON.stringify(a)),
		"reference_block_id": reference_block_id,
		"gas_limit": str(gas_limit),
		"payer": proposer_address,
		"proposal_key": {
			"address": proposer_address,
			"key_index": str(proposer_key_index),
			"sequence_number": str(proposer_sequence_number)
		},
		"authorizers": authorizers,
		"payload_signatures": [],
		"envelope_signatures": [{
			"address": proposer_address,
			"key_index": str(envelope_key_index),
			"signature": envelope_signature
		}]
	}
