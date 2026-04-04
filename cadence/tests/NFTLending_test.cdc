// cadence/tests/NFTLending_test.cdc
import Test
import "NFTLending"
import "EmergencyPause"

access(all) let deployer = Test.getAccount(0x0000000000000007)

access(all) fun setup() {
    // 1. Deploy GameToken (required by NFTLending)
    let tokenErr = Test.deployContract(
        name: "GameToken",
        path: "../contracts/core/GameToken.cdc",
        arguments: ["Gold", "GOLD", UFix64(1_000_000_000.0)]
    )
    Test.expect(tokenErr, Test.beNil())

    // 2. Deploy GameNFT (required by NFTLending)
    let nftErr = Test.deployContract(
        name: "GameNFT",
        path: "../contracts/core/GameNFT.cdc",
        arguments: []
    )
    Test.expect(nftErr, Test.beNil())

    // 3. Deploy EmergencyPause (required by NFTLending)
    let pauseErr = Test.deployContract(
        name: "EmergencyPause",
        path: "../contracts/systems/EmergencyPause.cdc",
        arguments: []
    )
    Test.expect(pauseErr, Test.beNil())

    // 4. Deploy NFTLending
    let lendingErr = Test.deployContract(
        name: "NFTLending",
        path: "../contracts/systems/NFTLending.cdc",
        arguments: []
    )
    Test.expect(lendingErr, Test.beNil())
}

access(all) fun testCreateRental() {
    let lender = deployer
    let borrower = Test.createAccount()

    // Create rental via inline transaction (allows getCurrentBlock() to work properly)
    let tx = Test.Transaction(
        code: "import \"NFTLending\"\n"
            .concat("transaction(borrower: Address) {\n")
            .concat("    execute {\n")
            .concat("        let rentalId = NFTLending.createRental(\n")
            .concat("            lender: 0x0000000000000007,\n")
            .concat("            borrower: borrower,\n")
            .concat("            nftId: 1,\n")
            .concat("            nftContractAddress: 0x0000000000000007,\n")
            .concat("            collateralAmount: 0.0,\n")
            .concat("            pricePerEpoch: 10.0,\n")
            .concat("            durationBlocks: 1000,\n")
            .concat("            capabilityControllerID: 1\n")
            .concat("        )\n")
            .concat("        assert(rentalId == 0, message: \"expected rentalId 0\")\n")
            .concat("    }\n")
            .concat("}"),
        authorizers: [],
        signers: [],
        arguments: [borrower.address]
    )
    Test.expect(Test.executeTransaction(tx), Test.beSucceeded())

    // Verify via script
    let result = Test.executeScript(
        "import NFTLending from 0x0000000000000007\n"
            .concat("access(all) fun main(lender: Address, rentalId: UInt64): Bool {\n")
            .concat("    return NFTLending.getRental(lender: lender, rentalId: rentalId) != nil\n")
            .concat("}"),
        [lender.address, UInt64(0)]
    )
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual(true, result.returnValue! as! Bool)
}
