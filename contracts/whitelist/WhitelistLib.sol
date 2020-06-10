pragma solidity ^0.6.2;

library  WhitelistLib {
    struct AllowedAddress {
        bool tradeable;
        uint256 lockPeriod;
        uint256 dailyLimit;
        uint256 dailyLimitToday;
        uint256 addedAt;
        uint256 recordTime;
    }
}