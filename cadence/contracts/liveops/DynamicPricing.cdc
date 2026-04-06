import "EmergencyPause"

// DynamicPricing: On-chain price table that admins update without contract redeployment.
// Game contracts import this and call getPrice() instead of hardcoding values.
access(all) contract DynamicPricing {

    access(all) entitlement PricingAdmin

    // priceTable: itemId -> price in UFix64 (GameToken units)
    access(all) var priceTable: {String: UFix64}
    // discountTable: itemId -> discount percentage (0-100)
    access(all) var discountTable: {String: UFix64}
    access(all) let AdminStoragePath: StoragePath

    access(all) event PriceUpdated(itemId: String, newPrice: UFix64)
    access(all) event DiscountSet(itemId: String, pct: UFix64, expiresAtBlock: UInt64)

    access(all) struct DiscountRecord {
        access(all) let pct: UFix64
        access(all) let expiresAtBlock: UInt64
        init(pct: UFix64, expiresAtBlock: UInt64) {
            self.pct = pct; self.expiresAtBlock = expiresAtBlock
        }
    }

    access(all) var discountRecords: {String: DiscountRecord}

    access(all) resource Admin {
        access(PricingAdmin) fun setPrice(itemId: String, price: UFix64) {
            DynamicPricing.priceTable[itemId] = price
            emit PriceUpdated(itemId: itemId, newPrice: price)
        }

        access(PricingAdmin) fun setDiscount(itemId: String, pct: UFix64, durationBlocks: UInt64) {
            pre { pct <= 100.0: "Discount cannot exceed 100%" }
            let expires = getCurrentBlock().height + durationBlocks
            DynamicPricing.discountRecords[itemId] = DiscountRecord(pct: pct, expiresAtBlock: expires)
            emit DiscountSet(itemId: itemId, pct: pct, expiresAtBlock: expires)
        }
    }

    // Returns effective price after any active discount
    access(all) fun getPrice(itemId: String): UFix64 {
        EmergencyPause.assertNotPaused()
        let base = DynamicPricing.priceTable[itemId] ?? panic("Unknown item: ".concat(itemId))
        if let rec = DynamicPricing.discountRecords[itemId] {
            if getCurrentBlock().height <= rec.expiresAtBlock {
                return base * (1.0 - rec.pct / 100.0)
            }
        }
        return base
    }

    init() {
        self.priceTable = {}
        self.discountTable = {}
        self.discountRecords = {}
        self.AdminStoragePath = /storage/DynamicPricingAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}
