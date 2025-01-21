// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Escrow {
    // State variables
    uint256 private lockerId = 1;
    address public owner;
    uint256 public solanaPoolBal = 1_000_000_000;

    // Contracts
    address immutable USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Storage
    mapping(uint256 => bytes32) public vault;

    // Events
    event FundsLocked(
        uint256 lockerId, address lockedBy, uint256 bridgeAmount, uint256 fee, address dstAddress, uint8 maxSlippage
    );
    event FundsUnlocked(uint256 amountUnlocked);

    // Constructor
    constructor() {
        owner = msg.sender;
    }

    // Functions
    function lockFunds(uint256 bridgeAmount, address dstAddress, uint8 maxSlippage) external {
        require(bridgeAmount < solanaPoolBal, "Bridge amount exceeds the LP balance.");
        uint256 fee = bridgeAmount / 100; // 1% as a fee

        // user must approve the spending on their behalf through the front end first
        IERC20(USDC_ADDRESS).transferFrom(msg.sender, address(this), bridgeAmount + fee);
        solanaPoolBal -= bridgeAmount;

        bytes32 lockedFundsHash =
            keccak256((abi.encodePacked(lockerId, msg.sender, bridgeAmount, fee, dstAddress, maxSlippage)));

        vault[lockerId] = lockedFundsHash;
        emit FundsLocked(lockerId, msg.sender, bridgeAmount, fee, dstAddress, maxSlippage);

        lockerId++;
    }

    function unlockFunds() external onlyOwner {
        uint256 contractBalance = IERC20(USDC_ADDRESS).balanceOf(address(this));
        require(contractBalance > 0, "No funds to unlock");
        IERC20(USDC_ADDRESS).transfer(owner, contractBalance);
        emit FundsUnlocked(contractBalance);
    }

    // Modifier
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}
