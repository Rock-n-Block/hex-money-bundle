pragma solidity ^0.6.2;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./WhitelistLib.sol";

contract HexWhitelist is Ownable, ReentrancyGuard {

    using WhitelistLib for WhitelistLib.AllowedAddress;

    mapping(address => WhitelistLib.AllowedAddress) internal dapps;
    mapping(address => WhitelistLib.AllowedAddress) internal referrals;

    function registerDappTradeable(address dappAddress, uint256 dailyLimit) public {
        _registerDapp(dappAddress, true, 0, dailyLimit);
    }

    function registerDappNonTradeable(address dappAddress, uint256 dailyLimit, uint256 lockPeriod) public {
        _registerDapp(dappAddress, true, lockPeriod, dailyLimit);
    }

    function registerReferralTradeable(address referralAddress, uint256 dailyLimit) public {
        _registerReferral(referralAddress, true, 0, dailyLimit);
    }

    function registerReferralNonTradeable(address referralAddress, uint256 dailyLimit, uint256 lockPeriod) public {
        _registerReferral(referralAddress, true, lockPeriod, dailyLimit);
    }

    function isRegisteredDapp(address dappAddress) public view returns (bool) {
        if (dapps[dappAddress].addedAt != 0) {
            return true;
        } else {
            return false;
        }
    }

    function getDappTradeable(address dappAddress) public view returns (bool) {
        return dapps[dappAddress].tradeable;
    }

    function getDappLockPeriod(address dappAddress) public view returns (uint256) {
        return dapps[dappAddress].lockPeriod;
    }

    function getDappDailyLimit(address dappAddress) public view returns (uint256) {
        return dapps[dappAddress].dailyLimit;
    }

    function isRegisteredReferral(address dappAddress) public view returns (bool) {
        if (dapps[dappAddress].addedAt != 0) {
            return true;
        } else {
            return false;
        }
    }

    function getReferralTradeable(address referralAddress) public view returns (bool) {
        return referrals[referralAddress].tradeable;
    }

    function getReferralLockPeriod(address referralAddress) public view returns (uint256) {
        return referrals[referralAddress].lockPeriod;
    }

    function getReferralDailyLimit(address referralAddress) public view returns (uint256) {
        return referrals[referralAddress].dailyLimit;
    }

    function _registerDapp(address dappAddress, bool tradeable, uint256 lockPeriod, uint256 dailyLimit) internal
    {
        dapps[dappAddress] = WhitelistLib.AllowedAddress({tradeable: tradeable, lockPeriod: lockPeriod, dailyLimit: dailyLimit, addedAt: block.number});
    }

    function _registerReferral(address referralAddress, bool tradeable, uint256 lockPeriod, uint256 dailyLimit) internal
    {
        referrals[referralAddress] = WhitelistLib.AllowedAddress({tradeable: tradeable, lockPeriod: lockPeriod, dailyLimit: dailyLimit, addedAt: block.number});
    }
}