//SPDX-License-Identifier: MIT

pragma solidity >=0.8.26;

contract MultiSigWallet {
    mapping(address => bool) public owners;
    uint256 public ownersCount;

    constructor () {
        owners[msg.sender] = true;
        ownersCount++;
    }

    modifier onlyOwner() {
        require(owners[msg.sender] == true, "Not an owner");
        _;
    }

    function addOwner(address newOwner) public onlyOwner {
        require(owners[newOwner] == false, "Already an owner");
        require(ownersCount < 5, "You cannot have more than 5 owners"); // arbitrarily max 5 owners
        owners[newOwner] = true;
        ownersCount++;
    }

    function removeOwner(address oldOwner) public onlyOwner {
        require(owners[oldOwner] == true, "Not an owner");
        require(ownersCount > 1, "You cannot remove the last owner"); // at least 1 owner
        owners[oldOwner] = false;
        ownersCount--;
    }

    function contains(address[] memory list, address target) internal pure returns (bool) {
        for (uint i = 0; i < list.length; i++) {
            if (list[i] == target) {
                return true;
            }
        }
        return false;
    }

    struct Transaction {
        address author;
        address[] hasVoted;
        address[] hasApproved;
        address payable to;
        uint256 amount;
        bool executed;
        uint256 startTimestamp;
        uint256 endTimestamp;
    }

    // State variables to control and register the transactions properly
    uint public nextTransactionId = 1;
    mapping(uint => Transaction) public transactions;
    uint public lockedBalance = 0;

    // Events to log the transactions
    event TransactionReceived(address indexed from, uint amount);
    event TransactionStart(uint indexed transactionId, address indexed author, address indexed to, uint amount);
    event TransactionApprove(uint indexed transactionId, address indexed approvedBy, address indexed to, uint amount);
    event TransactionDenied(uint indexed transactionId, address indexed deniedBy, address indexed to);
    event TransactionExecuted(uint indexed transactionId, address indexed executedBy, address indexed to, uint amount);

    // Functions to handle the transactions
    receive() external payable {
        emit TransactionReceived(msg.sender, msg.value);
    }

    function startTransaction(address payable to, uint amount) public onlyOwner {
        require (amount <= address(this).balance, "Insufficient balance");
        Transaction memory transaction = Transaction({
            author: msg.sender,
            hasVoted: new address[](0),
            hasApproved: new address[](0),
            to: to,
            amount: amount,
            executed: false,
            startTimestamp: block.timestamp,
            endTimestamp: 0
        });
        transactions[nextTransactionId] = transaction;
        lockedBalance += amount;
        emit TransactionStart(nextTransactionId, msg.sender, to, amount);
        nextTransactionId++;
    }

    function approveTransaction(uint transactionId) public onlyOwner {
        require (transactions[transactionId].executed == false, "Transaction already executed");
        require (!contains(transactions[transactionId].hasVoted, msg.sender), "You have already voted on this transaction");
        require (transactions[transactionId].author != msg.sender, "You cannot approve your own transaction");
        emit TransactionApprove(transactionId, msg.sender, transactions[transactionId].to, transactions[transactionId].amount);
        transactions[transactionId].hasVoted.push(msg.sender);
        transactions[transactionId].hasApproved.push(msg.sender);
    }

    function denyTransaction(uint transactionId) public onlyOwner {
        require (transactions[transactionId].executed == false, "Transaction already executed");
        require (!contains(transactions[transactionId].hasVoted, msg.sender), "You have already voted on this transaction");
        require (transactions[transactionId].author != msg.sender, "You cannot deny your own transaction");
        emit TransactionDenied(transactionId, msg.sender, transactions[transactionId].to);
        transactions[transactionId].hasVoted.push(msg.sender);
    }

    function executeTransaction(uint transactionId) public onlyOwner {
        require (transactions[transactionId].hasVoted.length == ownersCount, "All owners must vote");
        require (transactions[transactionId].executed == false, "Transaction already executed");
        require (transactions[transactionId].hasApproved.length >= ownersCount/2, "Transaction Denied. Not enough approvals");
        transactions[transactionId].executed = true;
        lockedBalance -= transactions[transactionId].amount;
        (bool success, ) = transactions[transactionId].to.call{value: transactions[transactionId].amount}("");
        require(success, "Transfer failed");
        emit TransactionExecuted(transactionId, msg.sender, transactions[transactionId].to, transactions[transactionId].amount);
    }

}
