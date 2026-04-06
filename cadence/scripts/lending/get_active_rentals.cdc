import "NFTLending"

access(all) fun main(borrowerAddress: Address): [UInt64] {
    return NFTLending.getActiveBorrowerRentals(borrower: borrowerAddress)
}
