// src/flow-bridge/unity/FlowWallet.cs
// Wallet integration for Unity games.
// WebGL: delegates to FCL via Application.ExternalCall/ExternalEval.
// Standalone/Mobile: uses WalletConnect (requires separate plugin).
using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FlowBridge
{
    public class FlowWallet : MonoBehaviour
    {
        public event Action<string> OnAuthenticated;
        public event Action<string> OnError;

        private string _address = string.Empty;
        private FlowClient _client;

        public void Initialize(FlowClient client)
        {
            _client = client;
        }

        public string Address => _address;
        public bool IsAuthenticated => !string.IsNullOrEmpty(_address);

        /// <summary>Start wallet authentication. Branches by platform.</summary>
        public void Authenticate()
        {
#if UNITY_WEBGL && !UNITY_EDITOR
            AuthenticateWeb();
#else
            AuthenticateWalletConnect();
#endif
        }

        private void AuthenticateWeb()
        {
            // FCL authentication via JavaScript interop
            Application.ExternalEval(@"
                (function() {
                    if (typeof window.fcl === 'undefined') {
                        console.error('FCL not loaded — add <script src=""https://cdn.jsdelivr.net/npm/@onflow/fcl""> to your WebGL template');
                        return;
                    }
                    window.fcl.authenticate().then(function(user) {
                        if (user && user.addr) {
                            window.godotFlowAddress = user.addr;
                            unityInstance.SendMessage('FlowWallet', 'OnWebAuthenticated', user.addr);
                        }
                    }).catch(function(e) {
                        console.error('FCL auth error:', e);
                    });
                })();
            ");
        }

        // Called by JS via SendMessage after FCL auth completes
        public void OnWebAuthenticated(string address)
        {
            _address = address;
            OnAuthenticated?.Invoke(address);
        }

        private void AuthenticateWalletConnect()
        {
            Debug.LogWarning("FlowWallet: WalletConnect requires the WalletConnect Unity SDK. See docs/flow/engine-integration/unity-flow-bridge.md");
            OnError?.Invoke("WalletConnect SDK not installed");
        }

        /// <summary>Sign a message. WebGL delegates to FCL; standalone requires WalletConnect.</summary>
        public async Task<(string signature, int keyIndex)> SignMessage(byte[] message)
        {
#if UNITY_WEBGL && !UNITY_EDITOR
            return await SignMessageWeb(message);
#else
            Debug.LogError("FlowWallet: Message signing on non-WebGL requires WalletConnect SDK");
            return (string.Empty, 0);
#endif
        }

        private TaskCompletionSource<(string sig, int keyIndex)> _sigTcs;

        private async Task<(string signature, int keyIndex)> SignMessageWeb(byte[] message)
        {
            _sigTcs = new TaskCompletionSource<(string, int)>();
            var hexMessage = BitConverter.ToString(message).Replace("-", "").ToLower();

            Application.ExternalEval($@"
                (function() {{
                    window.fcl.currentUser.signUserMessage('{hexMessage}').then(function(sigs) {{
                        if (sigs && sigs.length > 0) {{
                            var sig = sigs[0].signature;
                            var keyId = sigs[0].keyId || 0;
                            unityInstance.SendMessage('FlowWallet', 'OnMessageSigned', sig + ':' + keyId);
                        }}
                    }});
                }})();
            ");

            return await _sigTcs.Task;
        }

        // Called by JS via SendMessage after signing
        public void OnMessageSigned(string payload)
        {
            var parts = payload.Split(':');
            var sig = parts.Length > 0 ? parts[0] : string.Empty;
            var keyIdx = parts.Length > 1 ? int.Parse(parts[1]) : 0;
            _sigTcs?.SetResult((sig, keyIdx));
        }
    }
}
