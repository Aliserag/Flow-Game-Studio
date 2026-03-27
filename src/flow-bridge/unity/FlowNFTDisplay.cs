// src/flow-bridge/unity/FlowNFTDisplay.cs
// Unity component that fetches and displays NFT metadata from Flow.
// Attach to a GameObject with a RawImage (thumbnail) and Text/TMP components.
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.UI;
using TMPro;
using Newtonsoft.Json.Linq;

namespace FlowBridge
{
    public class FlowNFTDisplay : MonoBehaviour
    {
        [Header("UI References")]
        [SerializeField] private RawImage _thumbnailImage;
        [SerializeField] private TextMeshProUGUI _nameLabel;
        [SerializeField] private TextMeshProUGUI _descriptionLabel;
        [SerializeField] private TextMeshProUGUI _idLabel;

        [Header("Flow Client")]
        [SerializeField] private FlowClient _flowClient;

        private const string GET_NFT_SCRIPT = @"
            import NonFungibleToken from 0x1d7e57aa55817448
            import GameNFT from 0xGAMENFT_ADDRESS
            import MetadataViews from 0x1d7e57aa55817448
            access(all) fun main(addr: Address, id: UInt64): {String: AnyStruct}? {
                let collection = getAccount(addr)
                    .capabilities.get<&GameNFT.Collection>(GameNFT.CollectionPublicPath)
                    .borrow() ?? return nil
                let nft = collection.borrowNFT(id) ?? return nil
                let display = nft.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?
                return {
                    ""id"": id,
                    ""name"": display?.name ?? ""Unknown"",
                    ""description"": display?.description ?? """",
                    ""thumbnail"": display?.thumbnail?.uri() ?? """"
                }
            }
        ";

        /// <summary>Load and display NFT data for the given owner and NFT ID.</summary>
        public async Task DisplayNFT(string ownerAddress, ulong nftId)
        {
            if (_idLabel != null) _idLabel.text = $"#{nftId}";

            var args = new object[]
            {
                new { type = "Address", value = ownerAddress },
                new { type = "UInt64", value = nftId.ToString() }
            };

            var data = await _flowClient.ExecuteScript(GET_NFT_SCRIPT, args);
            if (data == null)
            {
                Debug.LogWarning($"FlowNFTDisplay: No data for NFT #{nftId}");
                return;
            }

            if (_nameLabel != null)
                _nameLabel.text = data["name"]?.ToString() ?? string.Empty;

            if (_descriptionLabel != null)
                _descriptionLabel.text = data["description"]?.ToString() ?? string.Empty;

            var thumbnailUri = data["thumbnail"]?.ToString() ?? string.Empty;
            if (!string.IsNullOrEmpty(thumbnailUri) && _thumbnailImage != null)
                await LoadThumbnail(thumbnailUri);
        }

        private async Task LoadThumbnail(string ipfsUri)
        {
            // Convert ipfs:// URI to HTTP gateway URL
            var httpUrl = ipfsUri.Replace("ipfs://", "https://ipfs.io/ipfs/");
            using var req = UnityWebRequestTexture.GetTexture(httpUrl);
            var op = req.SendWebRequest();
            while (!op.isDone) await Task.Yield();
            if (req.result == UnityWebRequest.Result.Success)
                _thumbnailImage.texture = DownloadHandlerTexture.GetContent(req);
            else
                Debug.LogWarning($"FlowNFTDisplay: Failed to load thumbnail from {httpUrl}: {req.error}");
        }
    }
}
