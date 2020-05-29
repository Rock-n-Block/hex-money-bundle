pragma solidity ^0.6.2;


import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./WhitelistLib.sol";

contract HexWhitelist is AccessControl, ReentrancyGuard {

    using WhitelistLib for WhitelistLib.AllowedAddress;

    mapping(address => WhitelistLib.AllowedAddress) internal dapps;
    mapping(address => WhitelistLib.AllowedAddress) internal referrals;

    constructor () public {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function registerDappTradeable(address dappAddress, uint256 dailyLimit) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        _registerDapp(dappAddress, true, 0, dailyLimit);
    }

    function registerDappNonTradeable(address dappAddress, uint256 dailyLimit, uint256 lockPeriod) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        _registerDapp(dappAddress, true, lockPeriod, dailyLimit);
    }

    function registerReferralTradeable(address referralAddress, uint256 dailyLimit) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        _registerReferral(referralAddress, true, 0, dailyLimit);
    }

    function registerReferralNonTradeable(address referralAddress, uint256 dailyLimit, uint256 lockPeriod) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        _registerReferral(referralAddress, true, lockPeriod, dailyLimit);
    }

    function unregisterDapp(address dappAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        dapps[dappAddress].tradeable = false;
        dapps[dappAddress].lockPeriod = 0;
        dapps[dappAddress].dailyLimit = 0;
        dapps[dappAddress].addedAt = 0;

    }

    function unregisterReferral(address referralAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        referrals[referralAddress].tradeable = false;
        referrals[referralAddress].lockPeriod = 0;
        referrals[referralAddress].dailyLimit = 0;
        referrals[referralAddress].addedAt = 0;
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