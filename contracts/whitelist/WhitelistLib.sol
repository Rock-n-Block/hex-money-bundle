pragma solidity ^0.6.2;

library  WhitelistLib {
    struct AllowedAddress {
        bool tradeable;
        uint256 lockPeriod;
        uint256 dailyLimit;
        uint256 addedAt;
    }
}