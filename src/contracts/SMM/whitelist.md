# Whitelist inheritance into Escrow

## Purpose

The purpose of this inheritance is to limit the fact that 2 contracts exist for only a difference of about 3 lines of code. So although inheritance is a great tool to use within the smart contracts, there are small differences in the logic such as the maxAmount that is used in the whitelist contract version, and the extended expirationTimestamp.

## When adding whitelist

1. Take out the owner functionality from escrow, and use the one that is on whitelist. 
2. Remove owner from the constructor
3. Add the onlyWhitelist modifier from the `createOrder` function. 
4. Add the whitelist limit in the createOrder function. 
5. Add the whitelist limit as a variable. 
6. Change the expiration timestamp to whatever the extended period of time is required. 
7. Remove the onlyOwner modifier, and use the one that is in Whitelist.sol, or override it. 
8. Add the batchAddToWhitelist call to the tests: 
    a. `address[] public whitelistAddresses;`
    b. `whitelistAddresses.push(user);`
    c. `escrow.batchAddToWhitelist(whitelistAddresses);`
