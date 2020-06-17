pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./WhitelistLib.sol";

contract HexWhitelist is AccessControl, ReentrancyGuard {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    uint256 public constant SECONDS_IN_DAY = 86400;

    using WhitelistLib for WhitelistLib.AllowedAddress;

    mapping(address => WhitelistLib.AllowedAddress) internal exchanges;
    mapping(address => WhitelistLib.AllowedAddress) internal dapps;
    mapping(address => WhitelistLib.AllowedAddress) internal referrals;

    uint256 internal whitelistRecordTime;

    modifier onlyAdminOrDeployerRole() {
        bool hasAdminRole = hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
        bool hasDeployerRole = hasRole(DEPLOYER_ROLE, _msgSender());
        require(hasAdminRole || hasDeployerRole, "Must have admin or deployer role");
        _;
    }

    constructor (address _adminAddress) public {
        _setupRole(DEPLOYER_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);

        whitelistRecordTime = SafeMath.add(block.timestamp, SafeMath.mul(1, SECONDS_IN_DAY));
    }
    function registerExchangeTradeable(address _address, uint256 dailyLimit) public onlyAdminOrDeployerRole {
        _registerExchange(_address, true, 0, dailyLimit);
    }

    function registerDappTradeable(address _address, uint256 dailyLimit) public onlyAdminOrDeployerRole {
        _registerDapp(_address, true, 0, dailyLimit);
    }

    function registerReferralTradeable(address _address, uint256 dailyLimit) public onlyAdminOrDeployerRole {
        _registerReferral(_address, true, 0, dailyLimit);
    }

    function registerExchangeNonTradeable(address _address, uint256 dailyLimit, uint256 lockPeriod) public onlyAdminOrDeployerRole {
        _registerExchange(_address, false, lockPeriod, dailyLimit);
    }

    function registerDappNonTradeable(address _address, uint256 dailyLimit, uint256 lockPeriod) public onlyAdminOrDeployerRole {
        _registerDapp(_address, false, lockPeriod, dailyLimit);
    }

    function registerReferralNonTradeable(address _address, uint256 dailyLimit, uint256 lockPeriod) public onlyAdminOrDeployerRole {
        _registerReferral(_address, false, lockPeriod, dailyLimit);
    }


    function unregisterExchange(address _address) public onlyAdminOrDeployerRole {
        delete exchanges[_address];
    }

    function unregisterDapp(address _address) public onlyAdminOrDeployerRole {
        delete dapps[_address];
    }

    function unregisterReferral(address _address) public onlyAdminOrDeployerRole {
        delete referrals[_address];
    }

    function setExchangepDailyLimit(address _address, uint256 _dailyLimit) public onlyAdminOrDeployerRole {
        exchanges[_address].dailyLimit = _dailyLimit;
    }

    function setDappDailyLimit(address _address, uint256 _dailyLimit) public onlyAdminOrDeployerRole {
        dapps[_address].dailyLimit = _dailyLimit;
    }

    function setReferralDailyLimit(address _address, uint256 _dailyLimit) public onlyAdminOrDeployerRole {
        referrals[_address].dailyLimit = _dailyLimit;
    }

    function setExchangeLockPeriod(address _address, uint256 _lockPeriod) public onlyAdminOrDeployerRole {
        require(!getExchangeTradeable(_address), "cannot set lock period to tradeable address");
        exchanges[_address].lockPeriod = _lockPeriod;
    }

    function setDappLockPeriod(address _address, uint256 _lockPeriod) public onlyAdminOrDeployerRole {
        require(!getExchangeTradeable(_address), "cannot set lock period to tradeable address");
        dapps[_address].lockPeriod = _lockPeriod;
    }

    function setReferralLockPeriod(address _address, uint256 _lockPeriod) public onlyAdminOrDeployerRole {
        require(!getExchangeTradeable(_address), "cannot set lock period to tradeable address");
        dapps[_address].lockPeriod = _lockPeriod;
    }

    function addToExchangeDailyLimit(address _address, uint256 amount) public {
        if (exchanges[_address].dailyLimit > 0) {
            if (isNewDayStarted(exchanges[_address].recordTime)) {
                exchanges[_address].dailyLimitToday = 0;
                exchanges[_address].recordTime = getNewRecordTime();
            }

            uint256 limitToday = dapps[_address].dailyLimitToday;
            require(SafeMath.add(limitToday, amount) < exchanges[_address].dailyLimit, "daily limit exceeded");

            exchanges[_address].dailyLimitToday = SafeMath.add(limitToday, amount);
        }
    }

    function addToDappDailyLimit(address _address, uint256 amount) public {
        if (dapps[_address].dailyLimit > 0) {
            if (isNewDayStarted(dapps[_address].recordTime)) {
                dapps[_address].dailyLimitToday = 0;
                dapps[_address].recordTime = getNewRecordTime();
            }

            uint256 limitToday = dapps[_address].dailyLimitToday;
            require(SafeMath.add(limitToday, amount) < dapps[_address].dailyLimit, "daily limit exceeded");

            dapps[_address].dailyLimitToday = SafeMath.add(limitToday, amount);
        }
    }

    function addToReferralDailyLimit(address _address, uint256 amount) public {
        if (referrals[_address].dailyLimit > 0) {
            if (isNewDayStarted(referrals[_address].recordTime)) {
                referrals[_address].dailyLimitToday = 0;
                referrals[_address].recordTime = getNewRecordTime();
            }

            uint256 limitToday = referrals[_address].dailyLimitToday;
            require(SafeMath.add(limitToday, amount) < referrals[_address].dailyLimit, "daily limit exceeded");

            referrals[_address].dailyLimitToday = SafeMath.add(limitToday, amount);
        }
    }


    function isRegisteredDapp(address _address) public view returns (bool) {
        return (dapps[_address].addedAt != 0) ? true : false;
    }

    function isRegisteredReferral(address _address) public view returns (bool) {
        if (dapps[_address].addedAt != 0) {
            return true;
        } else {
            return false;
        }
    }

    function isRegisteredDappOrReferral(address executionAddress) public view returns (bool) {
        if (isRegisteredDapp(executionAddress) || isRegisteredReferral(executionAddress)) {
            return true;
        } else {
            return false;
        }
    }

    function isRegisteredExchange(address _address) public view returns (bool) {
        if (exchanges[_address].addedAt != 0) {
            return true;
        } else {
            return false;
        }
    }

    function getExchangeTradeable(address _address) public view returns (bool) {
        return exchanges[_address].tradeable;
    }

    function getDappTradeable(address _address) public view returns (bool) {
        return dapps[_address].tradeable;
    }

    function getReferralTradeable(address _address) public view returns (bool) {
        return referrals[_address].tradeable;
    }

    function getDappOrReferralTradeable(address _address) public view returns (bool) {
        if (isRegisteredDapp(_address)) {
            return dapps[_address].tradeable;
        } else {
            return referrals[_address].tradeable;
        }
    }

    function getExchangeLockPeriod(address _address) public view returns (uint256) {
        return exchanges[_address].lockPeriod;
    }

    function getDappLockPeriod(address _address) public view returns (uint256) {
        return dapps[_address].lockPeriod;
    }

    function getReferralLockPeriod(address _address) public view returns (uint256) {
        return referrals[_address].lockPeriod;
    }

    function getDappOrReferralLockPeriod(address _address) public view returns (uint256) {
        if (isRegisteredDapp(_address)) {
            return dapps[_address].lockPeriod;
        } else {
            return referrals[_address].lockPeriod;
        }
    }

    function getDappDailyLimit(address _address) public view returns (uint256) {
        return dapps[_address].dailyLimit;
    }

    function getReferralDailyLimit(address _address) public view returns (uint256) {
        return referrals[_address].dailyLimit;
    }

    function getDappOrReferralDailyLimit(address _address) public view returns (uint256) {
        if (isRegisteredDapp(_address)) {
            return dapps[_address].dailyLimit;
        } else {
            return referrals[_address].dailyLimit;
        }
    }
    function getExchangeTodayMinted(address _address) public view returns (uint256) {
        return exchanges[_address].dailyLimitToday;
    }

    function getDappTodayMinted(address _address) public view returns (uint256) {
        return dapps[_address].dailyLimitToday;
    }

    function getReferralTodayMinted(address _address) public view returns (uint256) {
        return referrals[_address].dailyLimitToday;
    }

    function getExchangeRecordTimed(address _address) public view returns (uint256) {
        return exchanges[_address].recordTime;
    }

    function getDappRecordTimed(address _address) public view returns (uint256) {
        return dapps[_address].recordTime;
    }

    function getReferralRecordTimed(address _address) public view returns (uint256) {
        return referrals[_address].recordTime;
    }

    function getNewRecordTime() internal view returns (uint256) {
        return SafeMath.add(block.timestamp, SafeMath.mul(1, SECONDS_IN_DAY));
    }

    function isNewDayStarted(uint256 oldRecordTime) internal view returns (bool) {
        return block.timestamp > oldRecordTime ? true : false;
    }

    function _registerExchange(address _address, bool tradeable, uint256 lockPeriod, uint256 dailyLimit) internal
    {
        require(!isRegisteredDappOrReferral(_address), "address already registered as dapp or referral");
        require(!isRegisteredExchange(_address), "exchange already registered");
        exchanges[_address] = WhitelistLib.AllowedAddress({
            tradeable: tradeable,
            lockPeriod: lockPeriod,
            dailyLimit: dailyLimit,
            dailyLimitToday: 0,
            addedAt: block.timestamp,
            recordTime: getNewRecordTime()
            });
    }

    function _registerDapp(address _address, bool tradeable, uint256 lockPeriod, uint256 dailyLimit) internal
    {
        require(!isRegisteredExchange(_address) && !isRegisteredReferral(_address), "address already registered as exchange or referral");
        require(!isRegisteredDapp(_address), "address already registered");
        dapps[_address] = WhitelistLib.AllowedAddress({
            tradeable: tradeable,
            lockPeriod: lockPeriod,
            dailyLimit: dailyLimit,
            dailyLimitToday: 0,
            addedAt: block.timestamp,
            recordTime: getNewRecordTime()
            });
    }

    function _registerReferral(address _address, bool tradeable, uint256 lockPeriod, uint256 dailyLimit) internal
    {
        require(!isRegisteredExchange(_address) && !isRegisteredDapp(_address), "address already registered as exchange or referral");
        require(!isRegisteredReferral(_address), "address already registered");
        referrals[_address] = WhitelistLib.AllowedAddress({
            tradeable: tradeable,
            lockPeriod: lockPeriod,
            dailyLimit: dailyLimit,
            dailyLimitToday: 0,
            addedAt: block.timestamp,
            recordTime: getNewRecordTime()
            });
    }
}