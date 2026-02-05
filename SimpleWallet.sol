//SPDX-License-Identifier: MIT

pragma solidity >=0.8.26;

contract SimpleWallet {
    address payable public owner;

    constructor() payable {
        owner = payable(msg.sender);
    }

    receive() external payable {}

    modifier onlyOwner() {
    require(msg.sender == owner, "caller is not owner");
    _;
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "insufficient balance");
        owner.transfer(_amount);
    }

    function getBalance() external view returns(uint256) {
        return address(this).balance;
    }

}