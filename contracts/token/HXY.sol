pragma solidity ^0.6.2;


import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ERC20FreezableCapped.sol";
import "../WhitelistLib.sol";
import "../HexWhitelist.sol";
import "../HexMoneySettings.sol";

contract HXY is ERC20FreezableCapped, HexMoneySettings {
    bytes32 public constant EXCHANGE_ROLE = keccak256("EXCHANGE_ROLE");
    uint256 public constant MINIMAL_FREEZE_PERIOD = 7;    // 7 days

    using WhitelistLib for WhitelistLib.AllowedAddress;

    // latest freezing start date for user
    mapping (address => latestFreezing) internal latestFreezingData;

    uint256 internal teamLockPeriod;
    uint256 internal teamSupply = SafeMath.mul(12, 10 ** 14);

    uint256 internal totalFrozen;
    uint256 internal totalHxyMinted;

    uint256 internal hxyMintedMultiplier = 10 ** 3;
    uint256[] internal hxyRoundMintAmount = [750, 5000, 10000, 15000, 20000, 25000, 30000];
    uint256 internal baseHexToHxyRate = 10 ** 3;
    uint256[] internal hxyRoundBaseRate = [1, 2, 3, 4, 5, 6, 7];

    uint256 internal maxHxyRounds = 7;
    uint256 internal currentHxyRound;
    uint256 internal currentHxyRoundRate = 1000;

    struct latestFreezing {
        uint256 startDate;
        uint256 endDate;
        uint256 tokenAmount;
    }

    constructor(address _teamAddress, uint256 _teamLockPeriod)
    ERC20FreezableCapped(SafeMath.mul(60,  10 ** 14))        // 60,000,000
    ERC20("HXY", "HXY")
    public
    {
        _setupDecimals(8);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _mintForTeam(_teamAddress, _teamLockPeriod);
    }



    function getRemainingHxyInRound() public view returns (uint256) {
        return (hxyRoundMintAmount[currentHxyRound] * hxyMintedMultiplier) - totalHxyMinted;
    }

    function getTotalHxyInRound() public view returns (uint256) {
        return hxyRoundMintAmount[currentHxyRound] * hxyMintedMultiplier;
    }

    function getTotalHxyMinted() public view returns (uint256) {
        return totalHxyMinted;
    }

    function getCurrentHxyRound() public view returns (uint256) {
        return currentHxyRound;
    }

    function getCurrentHxyRate() public view returns (uint256) {
        return currentHxyRoundRate;
    }

    function getTotalFrozen() public view returns (uint256) {
        return totalFrozen;
    }

    function getTeamSupply() public view returns (uint256) {
        return teamSupply;
    }

    function getTeamLockPeriod() public view returns (uint256) {
        return teamLockPeriod;
    }

    function getLatestFreezingDate(address _addr) public view returns (uint256, uint256, uint256) {
        latestFreezing memory data = latestFreezingData[_addr];
        return (data.startDate, data.endDate, data.tokenAmount);
    }

    function setExchange(address newExchangeAddress) public onlyAdminRole {
        require(newExchangeAddress != address(0x0), "Invalid exchange address");
        _setupRole(EXCHANGE_ROLE, newExchangeAddress);
    }

    function mintFromExchange(address account, uint256 hexAmount) public {
        require(hasRole(EXCHANGE_ROLE, _msgSender()), "Must be executed from exchange");
        uint256 hxyAmount = SafeMath.div(hexAmount, currentHxyRoundRate);
        mint(account, hxyAmount);
    }

    function mintFromDapp(address account, uint256 amount) public {
        address dappAddress = _msgSender();
        require(whitelist.isRegisteredDapp(dappAddress), "must be executed from whitelisted dapp");

        if (whitelist.getDappTradeable(dappAddress)) {
            mint(account, amount);
        } else {
            uint256 lockPeriod = whitelist.getDappLockPeriod(dappAddress);
            uint256 freezeUntil = _daysToTimestamp(lockPeriod);
            mintAndFreezeTo(account, amount, freezeUntil);
            totalFrozen = SafeMath.add(totalFrozen, amount);
        }
    }


    function freezeHxy(uint256 lockAmount, uint256 freezeUntil) public {
        require(freezeUntil >= MINIMAL_FREEZE_PERIOD, "must be more than 7 days");

        uint256 startFreezeDate = latestFreezingData[_msgSender()].startDate;
        uint256 lockDate = _daysToTimestampFrom(startFreezeDate, MINIMAL_FREEZE_PERIOD);
        if (lockDate != 0 && block.timestamp >= lockDate) {
            releaseFrozen();
        }

        _freezeTo(_msgSender(), lockAmount, _getBaseLockDays());
        _setNewFreezeData(_msgSender(), block.timestamp, freezeUntil, lockAmount);
        totalFrozen = SafeMath.add(totalFrozen, lockAmount);
    }

    function releaseFrozen() public {
        uint256 startFreezeDate = latestFreezingData[_msgSender()].startDate;
        uint256 lockDate = _daysToTimestampFrom(startFreezeDate, MINIMAL_FREEZE_PERIOD);
        require(block.timestamp > lockDate, "minimum period not exceeded");

        uint256 endFreezeDate = latestFreezingData[_msgSender()].endDate;
        uint256 interestEnd = (block.timestamp >= endFreezeDate) ? endFreezeDate : block.timestamp;
        uint256 interestDays = SafeMath.div(SafeMath.sub(interestEnd, startFreezeDate), SECONDS_IN_DAY);

        uint256 frozenTokens = latestFreezingData[_msgSender()].tokenAmount;
        uint256 interestAmount = SafeMath.mul(SafeMath.div(frozenTokens, 1000), interestDays);

        _releaseOnce();

        _setNewFreezeData(_msgSender(), 0, 0, 0);
        mint(_msgSender(), interestAmount);


        totalFrozen = SafeMath.sub(totalFrozen, frozenTokens);
    }

    function releaseFrozenTeam() public onlyTeamRole {
        _releaseOnce();
    }

    function mint(address account, uint256 amount) internal {
        _recordMintedTokens(amount);
        _mint(account, amount);
    }

    function mintAndFreezeTo(address _to, uint _amount, uint256 _until) internal {
        _recordMintedTokens(_amount);
        _mintAndFreezeTo(_to, _amount, _until);
        _setNewFreezeData(_msgSender(), block.timestamp, _until, _amount);
    }

    function _recordMintedTokens(uint256 hxyAmount) internal {
        totalHxyMinted = SafeMath.add(totalHxyMinted, hxyAmount);

        if (currentHxyRound < maxHxyRounds && totalHxyMinted + hxyAmount >= getRemainingHxyInRound()) {
                _incrementHxyRateRound();
        }
    }

    function _mintForTeam(address _teamAddress, uint256 _teamLockPeriod) internal {
        _setupRole(TEAM_ROLE, _teamAddress);
        teamAddress = _teamAddress;
        teamLockPeriod = _teamLockPeriod;
        uint256 lockUntil = _daysToTimestamp(teamLockPeriod);
        _mintAndFreezeTo(teamAddress, teamSupply, lockUntil);
    }

    function _incrementHxyRateRound() internal returns (bool) {
        currentHxyRound++;
        currentHxyRoundRate = SafeMath.mul(hxyRoundBaseRate[currentHxyRound], baseHexToHxyRate);
        return true;
    }

    function _setNewFreezeData(address _to, uint256 _startDate, uint256 _endDate, uint256 _tokenAmount) internal {
        latestFreezingData[_to].startDate = _startDate;
        latestFreezingData[_to].endDate = _endDate;
        latestFreezingData[_to].tokenAmount = _tokenAmount;
    }

    function _getBaseLockDays() internal view returns (uint256) {
        return _daysToTimestamp(MINIMAL_FREEZE_PERIOD);
    }

    function _daysToTimestamp(uint256 lockDays) internal view returns(uint256) {
        return _daysToTimestampFrom(block.timestamp, lockDays);
    }

    function _daysToTimestampFrom(uint256 from, uint256 lockDays) internal pure returns(uint256) {
        return SafeMath.add(from, SafeMath.mul(lockDays, SECONDS_IN_DAY));
    }
}