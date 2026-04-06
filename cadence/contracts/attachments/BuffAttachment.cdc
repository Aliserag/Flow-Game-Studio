// BuffAttachment.cdc
// Time-limited stat boosts attached to any NFT.
// Buffs expire by block height — no admin action required to remove them.
// Multiple buffs of different types can be active simultaneously.

import "NonFungibleToken"

access(all) contract BuffAttachment {

    access(all) entitlement ApplyBuff
    access(all) entitlement RemoveBuff

    access(all) struct Buff {
        access(all) let buffType: String    // "attack_boost", "defense_boost", "xp_multiplier"
        access(all) let magnitude: UFix64   // e.g., 1.5 = 50% boost
        access(all) let appliedAtBlock: UInt64
        access(all) let expiresAtBlock: UInt64
        access(all) let source: String      // which system applied this buff

        init(buffType: String, magnitude: UFix64, durationBlocks: UInt64, source: String) {
            self.buffType = buffType
            self.magnitude = magnitude
            self.appliedAtBlock = getCurrentBlock().height
            self.expiresAtBlock = getCurrentBlock().height + durationBlocks
            self.source = source
        }

        access(all) view fun isActive(): Bool {
            return getCurrentBlock().height <= self.expiresAtBlock
        }
    }

    access(all) event BuffApplied(nftId: UInt64, buffType: String, magnitude: UFix64, expiresAtBlock: UInt64)
    access(all) event BuffExpired(nftId: UInt64, buffType: String)

    access(all) attachment Buffs for NonFungibleToken.NFT {

        access(all) var activeBuffs: {String: Buff}   // buffType -> Buff

        init() { self.activeBuffs = {} }

        // Get all currently active buffs (skips expired ones)
        access(all) view fun getActiveBuffs(): {String: Buff} {
            var result: {String: Buff} = {}
            for key in self.activeBuffs.keys {
                let buff = self.activeBuffs[key]!
                if buff.isActive() { result[key] = buff }
            }
            return result
        }

        // Get effective multiplier for a stat type (1.0 if no buff)
        access(all) view fun getMultiplier(_ buffType: String): UFix64 {
            if let buff = self.activeBuffs[buffType] {
                if buff.isActive() { return buff.magnitude }
            }
            return 1.0
        }

        access(ApplyBuff) fun applyBuff(buffType: String, magnitude: UFix64, durationBlocks: UInt64, source: String) {
            pre { magnitude >= 1.0: "Buff magnitude must be >= 1.0 (1.0 = no effect)" }
            let buff = Buff(buffType: buffType, magnitude: magnitude, durationBlocks: durationBlocks, source: source)
            self.activeBuffs[buffType] = buff
            emit BuffApplied(nftId: self.base.id, buffType: buffType, magnitude: magnitude, expiresAtBlock: buff.expiresAtBlock)
        }

        access(RemoveBuff) fun removeBuff(buffType: String) {
            pre { self.activeBuffs[buffType] != nil: "Buff not found" }
            self.activeBuffs.remove(key: buffType)
            emit BuffExpired(nftId: self.base.id, buffType: buffType)
        }
    }
}
