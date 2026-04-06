# /flow-evm

Guides integration of Flow EVM (Solidity) contracts with Cadence game contracts.

## When to Use Flow EVM vs Pure Cadence

| Use Cadence | Use Flow EVM |
|-------------|-------------|
| Core game logic, NFTs, VRF | Porting existing Solidity contracts |
| Resource-based ownership (safer) | ERC-20/ERC-721 interop with Ethereum ecosystem |
| Custom entitlement access control | Solidity developer team |
| Scheduler, governance | DeFi primitives (Uniswap-style AMM) |

**Recommendation:** Core game logic should always be Cadence. Use EVM only for ecosystem compatibility or when porting battle-tested Solidity contracts.

## Cross-VM Call Pattern

To call an EVM contract from Cadence:

1. Deploy the Solidity contract to Flow EVM (via `cast` or Hardhat with Flow EVM RPC)
2. ABI-encode the calldata in Cadence using `EVM.encodeABIWithSignature()`
3. Call via `EVMBridge.callContract()`
4. Decode the return value with `EVM.decodeABI()`

## EVM RPC Endpoints

- Testnet: `https://testnet.evm.nodes.onflow.org`
- Mainnet: `https://mainnet.evm.nodes.onflow.org`
- Chain ID (testnet): 545
- Chain ID (mainnet): 747

## Example: Mint ERC-721 from Cadence transaction

```cadence
import "EVMBridge"
import EVM from 0x0000000000000001

transaction(contractAddrHex: String, tokenId: UInt256) {
    let signerAddress: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.signerAddress = signer.address
    }

    execute {
        // ABI-encode: mint(address,uint256)
        // ... (use EVM.encodeABIWithSignature)
    }
}
```

When generating EVM integration code, always:
1. Check `docs/flow/evm-integration.md` for current RPC endpoints
2. Prefer Cadence-Owned Accounts (COA) over externally-owned EVM accounts
3. Document which logic lives in Cadence vs EVM and why
