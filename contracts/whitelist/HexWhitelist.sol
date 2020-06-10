pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./WhitelistLib.sol";

contract HexWhitelist is AccessControl, ReentrancyGuard {
    uint256 public constant SECONDS_IN_DAY = 86400;

    using WhitelistLib for WhitelistLib.AllowedAddress;

    mapping(address => WhitelistLib.AllowedAddress) internal dapps;
    mapping(address => WhitelistLib.AllowedAddress) internal referrals;

    uint256 internal whitelistRecordTime;

    constructor () public {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        whitelistRecordTime = SafeMath.add(block.timestamp, SafeMath.mul(1, SECONDS_IN_DAY));
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
        dapps[dappAddress].dailyLimitToday = 0;
        dapps[dappAddress].addedAt = 0;
        dapps[dappAddress].recordTime = 0;

    }

    function unregisterReferral(address referralAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        referrals[referralAddress].tradeable = false;
        referrals[referralAddress].lockPeriod = 0;
        referrals[referralAddress].dailyLimit = 0;
        referrals[referralAddress].dailyLimitToday = 0;
        referrals[referralAddress].addedAt = 0;
        referrals[referralAddress].recordTime = 0;
    }

    function addToDappDailyLimit(address dappAddress, uint256 amount) public {
        if (isNewDayStarted(dapps[dappAddress].recordTime)) {
            dapps[dappAddress].dailyLimitToday = 0;
            dapps[dappAddress].recordTime = getNewRecordTime();
        }

        uint256 dappLimitToday = dapps[dappAddress].dailyLimitToday;
        require(SafeMath.add(dappLimitToday, amount) < dapps[dappAddress].dailyLimit, "daily limit exceeded");

        dapps[dappAddress].dailyLimitToday = SafeMath.add(dappLimitToday, amount);
    }

    function addToReferralDailyLimit(address referralAddress, uint256 amount) public {
        if (isNewDayStarted(referrals[referralAddress].recordTime)) {
            referrals[referralAddress].dailyLimitToday = 0;
            referrals[referralAddress].recordTime = getNewRecordTime();
        }

        uint256 referralLimitToday = referrals[referralAddress].dailyLimitToday;
        require(SafeMath.add(referralLimitToday, amount) < referrals[referralAddress].dailyLimit, "daily limit exceeded");

        referrals[referralAddress].dailyLimitToday = SafeMath.add(referralLimitToday, amount);
    }

    function setDappDailyLimit(address dappAddress, uint256 _dailyLimit) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        dapps[dappAddress].dailyLimit = _dailyLimit;
    }

    function setReferralDailyLimit(address referralAddress, uint256 _dailyLimit) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to register");
        referrals[referralAddress].dailyLimit = _dailyLimit;
    }

    function isRegisteredDapp(address dappAddress) public view returns (bool) {
        return (dapps[dappAddress].addedAt != 0) ? true : false;
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

    function getNewRecordTime() internal view returns (uint256) {
        return SafeMath.add(block.timestamp, SafeMath.mul(1, SECONDS_IN_DAY));
    }

    function isNewDayStarted(uint256 oldRecordTime) internal view returns (bool) {
        return block.timestamp > oldRecordTime ? true : false;
    }

    function _registerDapp(address dappAddress, bool tradeable, uint256 lockPeriod, uint256 dailyLimit) internal
    {
        dapps[dappAddress] = WhitelistLib.AllowedAddress({
            tradeable: tradeable,
            lockPeriod: lockPeriod,
            dailyLimit: dailyLimit,
            dailyLimitToday: 0,
            addedAt: block.timestamp,
            recordTime: getNewRecordTime()
            });
    }

    function _registerReferral(address referralAddress, bool tradeable, uint256 lockPeriod, uint256 dailyLimit) internal
    {
        referrals[referralAddress] = WhitelistLib.AllowedAddress({
            tradeable: tradeable,
            lockPeriod: lockPeriod,
            dailyLimit: dailyLimit,
            dailyLimitToday: 0,
            addedAt: block.timestamp,
            recordTime: getNewRecordTime()
            });
    }
}