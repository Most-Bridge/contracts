// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/// @title Whitelist Module
///
/// @author Most Bridge (https://github.com/Most-Bridge)
///
/// @notice Manages address whitelisting for contract access
contract Whitelist {
    // address public owner;
    mapping(address => bool) private whitelist;

    /// @notice Ensures function caller is the owner
    // modifier onlyOwner() {
    //     require(msg.sender == owner, "Caller is not the owner");
    //     _;
    // }
    // TODO

    /// @notice Ensures function caller is whitelisted
    modifier onlyWhitelist() {
        require(whitelist[msg.sender], "Caller is not on the whitelist");
        _;
    }

    constructor() {
        // owner = msg.sender;
        // TODO
    }

    /// @notice Add addresses to the whitelist
    ///
    /// @param _addresses Array of addresses to whitelist
    function batchAddToWhitelist(address[] calldata _addresses) external {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = true;
        }
    }

    /// @notice Check if an address is whitelisted
    ///
    /// @param  _address The address to check
    ///
    /// @return bool Returns true if the address is whitelisted
    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }
}
