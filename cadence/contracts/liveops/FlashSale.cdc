import "EmergencyPause"
import "DynamicPricing"

// FlashSale: Time-limited sale events that operators can schedule on-chain.
// Automatically applies discounts via DynamicPricing during the sale window.
access(all) contract FlashSale {

    access(all) entitlement SaleAdmin

    access(all) struct SaleConfig {
        access(all) let saleId: UInt64
        access(all) let name: String
        access(all) let startBlock: UInt64
        access(all) let endBlock: UInt64
        access(all) let itemIds: [String]
        access(all) let discountPct: UFix64

        init(saleId: UInt64, name: String, startBlock: UInt64, endBlock: UInt64,
             itemIds: [String], discountPct: UFix64) {
            self.saleId = saleId; self.name = name
            self.startBlock = startBlock; self.endBlock = endBlock
            self.itemIds = itemIds; self.discountPct = discountPct
        }
    }

    access(all) var activeSales: {UInt64: SaleConfig}
    access(all) var nextSaleId: UInt64
    access(all) let AdminStoragePath: StoragePath

    access(all) event FlashSaleStarted(saleId: UInt64, name: String, endBlock: UInt64)
    access(all) event FlashSaleEnded(saleId: UInt64)

    access(all) resource Admin {
        access(SaleAdmin) fun scheduleSale(
            name: String,
            startBlock: UInt64,
            endBlock: UInt64,
            itemIds: [String],
            discountPct: UFix64
        ): UInt64 {
            EmergencyPause.assertNotPaused()
            pre {
                endBlock > startBlock: "End must be after start"
                discountPct <= 100.0: "Discount cannot exceed 100%"
            }
            let saleId = FlashSale.nextSaleId
            FlashSale.nextSaleId = saleId + 1

            let config = SaleConfig(
                saleId: saleId, name: name, startBlock: startBlock, endBlock: endBlock,
                itemIds: itemIds, discountPct: discountPct
            )
            FlashSale.activeSales[saleId] = config
            emit FlashSaleStarted(saleId: saleId, name: name, endBlock: endBlock)
            return saleId
        }

        access(SaleAdmin) fun cancelSale(saleId: UInt64) {
            FlashSale.activeSales.remove(key: saleId)
            emit FlashSaleEnded(saleId: saleId)
        }
    }

    // Returns true if item is currently in an active flash sale
    access(all) fun isOnFlashSale(itemId: String): Bool {
        let currentBlock = getCurrentBlock().height
        for sale in FlashSale.activeSales.values {
            if currentBlock >= sale.startBlock && currentBlock <= sale.endBlock {
                if sale.itemIds.contains(itemId) {
                    return true
                }
            }
        }
        return false
    }

    init() {
        self.activeSales = {}
        self.nextSaleId = 0
        self.AdminStoragePath = /storage/FlashSaleAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}
