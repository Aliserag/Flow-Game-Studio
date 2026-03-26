# src/flow-bridge/godot/flow_wallet.gd
# Wallet integration for Godot 4 games.
# On desktop: opens WalletConnect QR or deep link.
# On web (HTML5 export): delegates to FCL via JavaScriptBridge.
# On mobile: calls native Flow wallet app.
class_name FlowWallet
extends RefCounted

signal authenticated(address: String)
signal transaction_signed(signature: String, key_index: int)
signal error(message: String)

var _address: String = ""
var _client: FlowClient

func _init(client: FlowClient) -> void:
	_client = client

## Start wallet authentication flow.
## On web builds: calls FCL via JavaScriptBridge.
## On desktop/mobile: uses WalletConnect (requires GDExtension).
func authenticate() -> void:
	if OS.get_name() == "Web":
		_authenticate_web()
	else:
		_authenticate_walletconnect()

func _authenticate_web() -> void:
	# Call FCL via JavaScript bridge (HTML5 export only)
	# Requires window.fcl to be loaded in the HTML template
	JavaScriptBridge.eval("""
		(function() {
			if (typeof window.fcl === 'undefined') {
				console.error('FCL not loaded. Add FCL script to your HTML template.');
				return;
			}
			window.fcl.authenticate().then(function(user) {
				if (user && user.addr) {
					window.godot_flow_authenticated = user.addr;
				}
			}).catch(function(err) {
				console.error('FCL auth error:', err);
			});
		})();
	""")
	# Poll for result (FCL auth is async)
	_poll_web_auth()

func _poll_web_auth() -> void:
	await Engine.get_main_loop().create_timer(0.5).timeout
	var addr: String = JavaScriptBridge.eval("window.godot_flow_authenticated || ''")
	if addr != "":
		_address = addr
		authenticated.emit(addr)
	else:
		_poll_web_auth()  # Keep polling

func _authenticate_walletconnect() -> void:
	# WalletConnect v2 requires a GDExtension or native plugin
	# See: https://github.com/WalletConnect/walletconnect-monorepo
	push_warning("FlowWallet: WalletConnect requires the flow-walletconnect GDExtension. See docs/flow/engine-integration/godot-flow-bridge.md")
	error.emit("WalletConnect GDExtension not installed")

## Sign a message using the connected wallet.
## On web: delegates to FCL. On desktop: requires WalletConnect GDExtension.
func sign_message(message: PackedByteArray) -> Array:
	if OS.get_name() == "Web":
		return await _sign_web(message)
	push_error("FlowWallet: Signing on non-web requires WalletConnect GDExtension")
	return []

func _sign_web(message: PackedByteArray) -> Array:
	# FCL signing via JavaScriptBridge
	var hex_message := message.hex_encode()
	JavaScriptBridge.eval("""
		(function() {
			window.fcl.currentUser.signUserMessage('%s').then(function(sigs) {
				if (sigs && sigs.length > 0) {
					window.godot_flow_sig = sigs[0].signature;
					window.godot_flow_key_index = sigs[0].keyId;
				}
			});
		})();
	""" % hex_message)
	await Engine.get_main_loop().create_timer(1.0).timeout
	var sig: String = JavaScriptBridge.eval("window.godot_flow_sig || ''")
	var key_idx: int = int(JavaScriptBridge.eval("window.godot_flow_key_index || 0"))
	return [sig, key_idx]

func get_address() -> String: return _address
func is_authenticated() -> bool: return _address != ""
