// get_spot_price.cdc
// Returns the current bonding curve spot price and buy/sell quotes.

import BondingCurve from 0xBONDING_CURVE_ADDRESS

access(all) fun main(buyAmount: UFix64, sellAmount: UFix64): {String: UFix64} {
    return {
        "spotPrice": BondingCurve.spotPrice(),
        "buyQuote": BondingCurve.buyQuote(amount: buyAmount),
        "sellQuote": BondingCurve.sellQuote(amount: sellAmount),
        "currentSupply": BondingCurve.currentSupply
    }
}
