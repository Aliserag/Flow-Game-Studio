import Test
import "NFTLending"
import "EmergencyPause"

access(all) fun testCreateRental() {
    let lender = Test.getAccount(0x0000000000000001)
    let borrower = Test.getAccount(0x0000000000000002)

    Test.deployContract(name: "EmergencyPause", path: "../contracts/systems/EmergencyPause.cdc", arguments: [])
    Test.deployContract(name: "NFTLending", path: "../contracts/systems/NFTLending.cdc", arguments: [])

    let rentalId = NFTLending.createRental(
        lender: lender.address,
        borrower: borrower.address,
        nftId: 1,
        nftContractAddress: lender.address,
        collateralAmount: 0.0,
        pricePerEpoch: 10.0,
        durationBlocks: 1000,
        capabilityControllerID: 1
    )

    Test.assertEqual(0 as UInt64, rentalId)

    let terms = NFTLending.getRental(lender: lender.address, rentalId: 0)
    Test.assert(terms != nil)
    Test.assertEqual(lender.address, terms!.lender)
    Test.assertEqual(borrower.address, terms!.borrower)
    Test.assertEqual(false, terms!.isExpired())
}
