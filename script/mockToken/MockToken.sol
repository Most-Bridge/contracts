// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MostToken", "MOST") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
        _mint(address(0x682a550cc99C02e12Caeb40B2C745E2Daa003215), 1_000_000 * 10 ** decimals());
        _mint(address(0xe727dbADBB18c998e5DeE2faE72cBCFfF2e6d03D), 1_000_000 * 10 ** decimals());
        _mint(address(0xAbDCA010DF48e6522B4476d3c6e61EBcc5C4523D), 1_000_000 * 10 ** decimals());
    }
}
