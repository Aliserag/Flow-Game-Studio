// EquipmentAttachment.cdc
// Adds equipment slots to ANY NFT that is a NonFungibleToken.NFT subtype.
// The attachment travels with the NFT — if the NFT is transferred, the
// equipment slots go with it. The new owner inherits the equipped items.
//
// DESIGN NOTE: We attach to NonFungibleToken.NFT (the interface) so this
// works with GameNFT, GameItem, and any future NFT contract in the studio.

import "NonFungibleToken"
import "GameItem"

access(all) contract EquipmentAttachment {

    // Entitlement to modify equipment — granted to the NFT owner only
    access(all) entitlement Equip
    access(all) entitlement Unequip

    // The slot names and what's equipped in each
    access(all) struct EquipmentSlotData {
        access(all) let slot: String    // "weapon", "armor", "accessory"
        access(all) var equippedItemId: UInt64?
        access(all) var equippedItemName: String?

        init(slot: String) {
            self.slot = slot
            self.equippedItemId = nil
            self.equippedItemName = nil
        }
    }

    access(all) event ItemEquipped(nftId: UInt64, slot: String, itemId: UInt64, itemName: String)
    access(all) event ItemUnequipped(nftId: UInt64, slot: String, itemId: UInt64)

    // The attachment itself — one per NFT, holds all equipment slots
    access(all) attachment Equipment for NonFungibleToken.NFT {

        access(all) var slots: {String: EquipmentSlotData}

        init() {
            // Default slots — extend by calling addSlot()
            self.slots = {
                "weapon":    EquipmentSlotData(slot: "weapon"),
                "armor":     EquipmentSlotData(slot: "armor"),
                "accessory": EquipmentSlotData(slot: "accessory"),
            }
        }

        // Read the base NFT's ID via the built-in `base` reference
        access(all) view fun nftId(): UInt64 {
            return self.base.id
        }

        access(all) view fun getSlot(_ slot: String): EquipmentSlotData? {
            return self.slots[slot]
        }

        access(all) view fun isSlotFilled(_ slot: String): Bool {
            return self.slots[slot]?.equippedItemId != nil
        }

        // Equip an item into a slot
        access(Equip) fun equip(slot: String, itemId: UInt64, itemName: String) {
            pre {
                self.slots[slot] != nil: "Unknown slot: ".concat(slot)
                self.slots[slot]!.equippedItemId == nil: "Slot already occupied — unequip first"
            }
            var slotData = self.slots[slot]!
            slotData.equippedItemId = itemId
            slotData.equippedItemName = itemName
            self.slots[slot] = slotData
            emit ItemEquipped(nftId: self.base.id, slot: slot, itemId: itemId, itemName: itemName)
        }

        // Unequip an item from a slot
        access(Unequip) fun unequip(slot: String): UInt64 {
            pre {
                self.slots[slot] != nil: "Unknown slot: ".concat(slot)
                self.slots[slot]!.equippedItemId != nil: "Slot is empty"
            }
            var slotData = self.slots[slot]!
            let itemId = slotData.equippedItemId!
            slotData.equippedItemId = nil
            slotData.equippedItemName = nil
            self.slots[slot] = slotData
            emit ItemUnequipped(nftId: self.base.id, slot: slot, itemId: itemId)
            return itemId
        }

        // Add a custom slot (e.g., "mount", "rune_1", "rune_2")
        access(Equip) fun addSlot(name: String) {
            pre { self.slots[name] == nil: "Slot already exists" }
            self.slots[name] = EquipmentSlotData(slot: name)
        }
    }
}
