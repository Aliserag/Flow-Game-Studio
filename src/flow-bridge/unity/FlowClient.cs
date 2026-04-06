// src/flow-bridge/unity/FlowClient.cs
// Flow REST API client for Unity.
// Uses UnityWebRequest to call the Flow Access Node REST API.
// FCL is JS-only; Unity uses REST directly.
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Networking;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace FlowBridge
{
    public class FlowClient : MonoBehaviour
    {
        public enum Network { Emulator, Testnet, Mainnet }

        [SerializeField] private Network _network = Network.Testnet;

        private string BaseUrl => _network switch
        {
            Network.Mainnet => "https://rest-mainnet.onflow.org",
            Network.Emulator => "http://localhost:8888",
            _ => "https://rest-testnet.onflow.org"
        };

        /// <summary>Execute a Cadence script (read-only, no signing).</summary>
        public async Task<JToken> ExecuteScript(string cadenceCode, object[] arguments = null)
        {
            var payload = new
            {
                script = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(cadenceCode)),
                arguments = arguments != null
                    ? Array.ConvertAll(arguments, a => JsonConvert.SerializeObject(a))
                    : Array.Empty<string>()
            };
            var response = await PostAsync("/v1/scripts", payload);
            if (response == null) return null;
            var base64Value = response["value"]?.ToString();
            if (string.IsNullOrEmpty(base64Value)) return null;
            var decoded = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(base64Value));
            return JToken.Parse(decoded);
        }

        /// <summary>Get account info (keys, balance, contracts).</summary>
        public async Task<JObject> GetAccount(string address)
        {
            return await GetAsync($"/v1/accounts/{address.TrimStart('0').TrimStart('x')}") as JObject;
        }

        /// <summary>Get NFT IDs owned by an account's GameNFT collection.</summary>
        public async Task<List<ulong>> GetNFTIds(string ownerAddress)
        {
            const string script = @"
                import NonFungibleToken from 0x1d7e57aa55817448
                import GameNFT from 0xGAMENFT_ADDRESS
                access(all) fun main(addr: Address): [UInt64] {
                    return getAccount(addr)
                        .capabilities.get<&GameNFT.Collection>(GameNFT.CollectionPublicPath)
                        .borrow()?.getIDs() ?? []
                }
            ";
            var args = new[] { new { type = "Address", value = ownerAddress } };
            var result = await ExecuteScript(script, args);
            return result?.ToObject<List<ulong>>() ?? new List<ulong>();
        }

        /// <summary>Get GameToken balance for an account.</summary>
        public async Task<decimal> GetTokenBalance(string ownerAddress)
        {
            const string script = @"
                import FungibleToken from 0xf233dcee88fe0abe
                import GameToken from 0xGAMETOKEN_ADDRESS
                access(all) fun main(addr: Address): UFix64 {
                    return getAccount(addr)
                        .capabilities.get<&GameToken.Vault>(GameToken.VaultPublicPath)
                        .borrow()?.balance ?? 0.0
                }
            ";
            var args = new[] { new { type = "Address", value = ownerAddress } };
            var result = await ExecuteScript(script, args);
            return result != null ? result.Value<decimal>() : 0m;
        }

        /// <summary>Send a signed transaction. Returns transaction ID.</summary>
        public async Task<string> SendTransaction(
            string cadenceCode,
            object[] arguments,
            string authorizerAddress,
            Func<byte[], Task<(string signature, int keyIndex)>> signatureProvider)
        {
            var block = await GetAsync("/v1/blocks?height=sealed");
            var refBlockId = block?[0]?["id"]?.ToString() ?? block?["id"]?.ToString();

            var account = await GetAccount(authorizerAddress);
            var seqNum = account?["keys"]?[0]?["sequence_number"]?.Value<int>() ?? 0;

            var tx = new FlowTransaction
            {
                Script = cadenceCode,
                Arguments = arguments,
                ReferenceBlockId = refBlockId,
                GasLimit = 999,
                ProposerAddress = authorizerAddress,
                ProposerKeyIndex = 0,
                ProposerSequenceNumber = seqNum,
                Authorizers = new[] { authorizerAddress }
            };

            var envelopeMessage = tx.BuildEnvelopeMessage();
            var (sig, keyIdx) = await signatureProvider(envelopeMessage);
            tx.EnvelopeSignature = sig;
            tx.EnvelopeKeyIndex = keyIdx;

            var result = await PostAsync("/v1/transactions", tx.ToPayload());
            return result?["id"]?.ToString();
        }

        /// <summary>Poll transaction status until sealed or timeout.</summary>
        public async Task<JObject> WaitForSeal(string txId, float timeoutSeconds = 30f)
        {
            var deadline = DateTime.UtcNow.AddSeconds(timeoutSeconds);
            while (DateTime.UtcNow < deadline)
            {
                await Task.Delay(1000);
                var status = await GetAsync($"/v1/transactions/{txId}/results");
                var statusStr = status?["status"]?.ToString();
                if (statusStr is "SEALED" or "EXPIRED")
                    return status as JObject;
            }
            return new JObject { ["status"] = "TIMEOUT" };
        }

        private async Task<JToken> GetAsync(string path)
        {
            using var req = UnityWebRequest.Get(BaseUrl + path);
            req.SetRequestHeader("Content-Type", "application/json");
            var op = req.SendWebRequest();
            while (!op.isDone) await Task.Yield();
            if (req.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"FlowClient GET {path}: {req.error}");
                return null;
            }
            return JToken.Parse(req.downloadHandler.text);
        }

        private async Task<JToken> PostAsync(string path, object body)
        {
            var json = JsonConvert.SerializeObject(body);
            var bytes = System.Text.Encoding.UTF8.GetBytes(json);
            using var req = new UnityWebRequest(BaseUrl + path, "POST");
            req.uploadHandler = new UploadHandlerRaw(bytes);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            var op = req.SendWebRequest();
            while (!op.isDone) await Task.Yield();
            if (req.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"FlowClient POST {path}: {req.error}");
                return null;
            }
            return JToken.Parse(req.downloadHandler.text);
        }
    }

    /// <summary>Flow transaction builder and signer.</summary>
    public class FlowTransaction
    {
        public string Script { get; set; }
        public object[] Arguments { get; set; }
        public string ReferenceBlockId { get; set; }
        public int GasLimit { get; set; } = 999;
        public string ProposerAddress { get; set; }
        public int ProposerKeyIndex { get; set; }
        public int ProposerSequenceNumber { get; set; }
        public string[] Authorizers { get; set; }
        public string EnvelopeSignature { get; set; }
        public int EnvelopeKeyIndex { get; set; }

        /// <summary>Build envelope bytes for signing. Simplified — use Flow Go SDK for production RLP encoding.</summary>
        public byte[] BuildEnvelopeMessage()
        {
            var message = $"{Script.GetHashCode()}{ReferenceBlockId}{ProposerAddress}{ProposerKeyIndex}{ProposerSequenceNumber}";
            return System.Text.Encoding.UTF8.GetBytes(message);
        }

        /// <summary>Serialize to Flow REST API /v1/transactions payload.</summary>
        public object ToPayload() => new
        {
            script = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(Script)),
            arguments = Arguments != null
                ? Array.ConvertAll(Arguments, a => JsonConvert.SerializeObject(a))
                : Array.Empty<string>(),
            reference_block_id = ReferenceBlockId,
            gas_limit = GasLimit.ToString(),
            payer = ProposerAddress,
            proposal_key = new
            {
                address = ProposerAddress,
                key_index = ProposerKeyIndex.ToString(),
                sequence_number = ProposerSequenceNumber.ToString()
            },
            authorizers = Authorizers ?? Array.Empty<string>(),
            payload_signatures = Array.Empty<object>(),
            envelope_signatures = new[]
            {
                new
                {
                    address = ProposerAddress,
                    key_index = EnvelopeKeyIndex.ToString(),
                    signature = EnvelopeSignature ?? string.Empty
                }
            }
        };
    }
}
