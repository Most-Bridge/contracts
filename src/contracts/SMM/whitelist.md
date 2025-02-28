# Whitelist inheritance into Escrow

## Purpose

The purpose of this inheritance is to limit the fact that 2 contracts exist for only a difference of about 3 lines of code. So although inheritance is a great tool to use within the smart contracts, there are small differences in the logic such as the maxAmount that is used in the whitelist contract version, and the extended expirationTimestamp.

## When removing whitelist

Check all of the `TODO` comments

1. bring owner back to the escrow.sol and away from the whitelist.sol
2. set owner in the constructor
3. remove the onlyWhitelist modifier from the `createOrder` function
4. remove the whitelist limit in the createOrder function, as well as remove the variable
5. change the expiration timestamp to 1 day
6. bring the onlyOwner modifier back to escrow
7. remove the batchAddToWhitelist call from the tests
