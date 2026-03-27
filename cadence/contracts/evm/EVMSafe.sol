// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal Gnosis Safe-inspired multisig for Flow EVM admin operations.
// M-of-N signature threshold required for all admin calls.
contract EVMSafe {
    uint256 public threshold;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public nonce;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        mapping(address => bool) confirmed;
    }

    Transaction[] public transactions;

    event TransactionSubmitted(uint256 indexed txIndex, address indexed owner);
    event TransactionConfirmed(uint256 indexed txIndex, address indexed owner);
    event TransactionExecuted(uint256 indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length >= _threshold && _threshold > 0, "Invalid threshold");
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0) && !isOwner[_owners[i]], "Invalid owner");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        threshold = _threshold;
    }

    function submitTransaction(address to, uint256 value, bytes calldata data)
        external onlyOwner returns (uint256 txIndex)
    {
        txIndex = transactions.length;
        transactions.push();
        Transaction storage t = transactions[txIndex];
        t.to = to; t.value = value; t.data = data;
        emit TransactionSubmitted(txIndex, msg.sender);
        confirmTransaction(txIndex);
    }

    function confirmTransaction(uint256 txIndex) public onlyOwner {
        Transaction storage t = transactions[txIndex];
        require(!t.executed, "Already executed");
        require(!t.confirmed[msg.sender], "Already confirmed");
        t.confirmed[msg.sender] = true;
        t.confirmations++;
        emit TransactionConfirmed(txIndex, msg.sender);
        if (t.confirmations >= threshold) executeTransaction(txIndex);
    }

    function executeTransaction(uint256 txIndex) internal {
        Transaction storage t = transactions[txIndex];
        t.executed = true;
        (bool success,) = t.to.call{value: t.value}(t.data);
        require(success, "Execution failed");
        emit TransactionExecuted(txIndex);
    }

    receive() external payable {}
}
