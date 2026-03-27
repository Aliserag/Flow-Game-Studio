import "StakingPool"

transaction(amount: UFix64) {
    let stakerAddress: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.stakerAddress = signer.address
    }

    execute {
        StakingPool.requestUnstake(staker: self.stakerAddress, amount: amount)
        log("Unstake requested: ".concat(amount.toString()))
    }
}
