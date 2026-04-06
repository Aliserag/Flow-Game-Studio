// BondingCurve.cdc
// Linear bonding curve for GameToken primary issuance.
// Price increases as supply increases: price = basePrice + slope * currentSupply
// This creates automatic price discovery without an AMM pool needing liquidity.
//
// Formula: price(supply) = basePrice + (slope x supply)
// Buy cost: integral from supply to supply+amount = basePrice*amount + slope*(supply*amount + amount^2/2)
// Sell return: same integral in reverse (minus a spread for treasury)

import "FungibleToken"
import "GameToken"
import "EmergencyPause"

access(all) contract BondingCurve {

    access(all) entitlement CurveAdmin

    // Curve parameters (set at init, adjustable by admin)
    access(all) var basePrice: UFix64     // minimum price per token
    access(all) var slope: UFix64         // price increase per token in supply
    access(all) var sellSpreadPct: UFix64 // % below buy price for sells (e.g., 5.0 = 5%)
    access(all) var currentSupply: UFix64 // tokens issued through this curve

    access(all) let ReserveStoragePath: StoragePath
    access(all) let AdminStoragePath: StoragePath

    access(all) event TokensBought(buyer: Address, tokenAmount: UFix64, flowPaid: UFix64, newSupply: UFix64)
    access(all) event TokensSold(seller: Address, tokenAmount: UFix64, flowReceived: UFix64, newSupply: UFix64)

    // Spot price at current supply
    access(all) view fun spotPrice(): UFix64 {
        return BondingCurve.basePrice + (BondingCurve.slope * BondingCurve.currentSupply)
    }

    // Cost to buy `amount` tokens starting from currentSupply
    access(all) view fun buyQuote(amount: UFix64): UFix64 {
        // Integral: basePrice*amount + slope*(currentSupply*amount + amount*amount/2)
        let linearCost = BondingCurve.basePrice * amount
        let curveCost = BondingCurve.slope * (BondingCurve.currentSupply * amount + amount * amount / 2.0)
        return linearCost + curveCost
    }

    // Return for selling `amount` tokens (includes sell spread discount)
    access(all) view fun sellQuote(amount: UFix64): UFix64 {
        pre { amount <= BondingCurve.currentSupply: "Cannot sell more than current supply" }
        let grossReturn = BondingCurve.basePrice * amount
            + BondingCurve.slope * ((BondingCurve.currentSupply - amount) * amount + amount * amount / 2.0)
        // Apply sell spread (treasury keeps the spread)
        return grossReturn * ((100.0 - BondingCurve.sellSpreadPct) / 100.0)
    }

    // Buy tokens by depositing FLOW into the reserve
    access(all) fun buy(
        buyer: Address,
        payment: @{FungibleToken.Vault},
        minTokens: UFix64,
        minterRef: &GameToken.Minter,
        tokenReceiver: &{FungibleToken.Receiver}
    ) {
        EmergencyPause.assertNotPaused()
        let flowAmount = payment.balance
        let tokenAmount = BondingCurve.tokensForFlow(flowAmount)
        assert(tokenAmount >= minTokens, message: "Slippage exceeded")

        // Store FLOW in reserve vault
        let reserve = BondingCurve.account.storage.borrow<&{FungibleToken.Receiver}>(
            from: BondingCurve.ReserveStoragePath
        )!
        reserve.deposit(from: <-payment)

        // Mint tokens to buyer
        let tokens <- minterRef.mintTokens(amount: tokenAmount)
        tokenReceiver.deposit(from: <-tokens)

        BondingCurve.currentSupply = BondingCurve.currentSupply + tokenAmount
        emit TokensBought(buyer: buyer, tokenAmount: tokenAmount, flowPaid: flowAmount, newSupply: BondingCurve.currentSupply)
    }

    // Calculate tokens receivable for a given FLOW amount (Newton's method approximation)
    access(all) view fun tokensForFlow(_ flowAmount: UFix64): UFix64 {
        // Quadratic solve: slope/2 * t^2 + (basePrice + slope*supply) * t - flowAmount = 0
        // Using quadratic formula: t = (-b + sqrt(b^2 + 2*a*flowAmount)) / a
        // where a = slope/2, b = basePrice + slope*currentSupply
        let a = BondingCurve.slope / 2.0
        let b = BondingCurve.basePrice + BondingCurve.slope * BondingCurve.currentSupply
        if a == 0.0 { return flowAmount / b }  // linear case
        // UFix64 has no sqrt — approximate via 10 iterations of Newton's method
        var x = flowAmount / b  // initial guess
        var i = 0
        while i < 10 {
            let fx = a * x * x + b * x - flowAmount
            let fpx = 2.0 * a * x + b
            if fpx == 0.0 { break }
            let delta = fx / fpx
            if delta < 0.000001 { break }
            x = x - delta
            i = i + 1
        }
        return x
    }

    access(all) resource Admin {
        access(CurveAdmin) fun setParameters(basePrice: UFix64, slope: UFix64, sellSpread: UFix64) {
            BondingCurve.basePrice = basePrice
            BondingCurve.slope = slope
            BondingCurve.sellSpreadPct = sellSpread
        }
    }

    init(basePrice: UFix64, slope: UFix64, sellSpreadPct: UFix64) {
        self.basePrice = basePrice
        self.slope = slope
        self.sellSpreadPct = sellSpreadPct
        self.currentSupply = 0.0
        self.ReserveStoragePath = /storage/BondingCurveReserve
        self.AdminStoragePath = /storage/BondingCurveAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}
