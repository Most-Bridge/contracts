// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * Interface for the Facts Registry contract by Herodotus
 * Takes in the account, a blockNumber (time) and the slot, returns the value of the slot
 */
interface IFactsRegistry {
    function accountStorageSlotValues(address account, uint256 blockNumber, bytes32 slot)
        external
        view
        returns (bytes32);
}
