pragma solidity ^0.6.2;


import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ERC20FreezableCapped.sol";
import "../WhitelistLib.sol";
import "../HexWhitelist.sol";
import "../HexMoneySettings.sol";

contract HXY is ERC20FreezableCapped, HexMoneySettings {
    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");
    bytes32 public constant EXCHANGE_ROLE = keccak256("EXCHANGE_ROLE");

    using WhitelistLib for WhitelistLib.AllowedAddress;

    address internal teamAddress;
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

    constructor(address _teamAddress, uint256 _teamLockPeriod)
    ERC20FreezableCapped(SafeMath.mul(60,  10 ** 14))        // 60,000,000
    ERC20("HXY", "HXY")
    public
    {
        _setupDecimals(8);
        _mintForTeam(_teamAddress, _teamLockPeriod);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
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

    function getTeamAddress() public view returns (address) {
        return teamAddress;
    }

    function getTeamSupply() public view returns (uint256) {
        return teamSupply;
    }

    function getTeamLockPeriod() public view returns (uint256) {
        return teamLockPeriod;
    }

    function setExchange(address newExchangeAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        require(newExchangeAddress != address(0x0), "Invalid exchange address");
        _setupRole(EXCHANGE_ROLE, newExchangeAddress);
    }

    function mintFromExchange(address account, uint256 hexAmount) public {
        require(hasRole(EXCHANGE_ROLE, _msgSender()), "Must be executed from exchange");
        uint256 hxyAmount = SafeMath.div(hexAmount, currentHxyRoundRate);
        mint(account, hxyAmount);
    }

    function mintFromDapp(address account, uint256 amount) public {
        address dappAddress = msg.sender;
        require(whitelist.isRegisteredDapp(dappAddress), "must be executed from whitelisted dapp");

        if (whitelist.getDappTradeable(dappAddress)) {
            mint(account, amount);
        } else {
            uint256 lockPeriod = whitelist.getDappLockPeriod(dappAddress);
            uint256 freezeUntil = _daysToTimestamp(lockPeriod);
            _mintAndFreezeTo(account, amount, freezeUntil);
            totalFrozen = SafeMath.add(totalFrozen, amount);
        }
    }


    function freezeHxy(uint256 lockAmount, uint256 lockDays) public {
        require(lockDays >= 7, "must be more than 7 days");
        (uint256 lockDate, uint256 frozenTokens) = getFreezing(msg.sender, 0);
        if (lockDate != 0) {
            if (block.timestamp >= lockDate) {
                releaseFrozen();
            }
        }

        uint256 freezeUntil = _daysToTimestamp(lockDays);
        _freezeTo(msg.sender, lockAmount, freezeUntil);
        totalFrozen = SafeMath.add(totalFrozen, lockAmount);
    }

    function releaseFrozen() public {
        //uint256 frozenTokens = freezingBalanceOf(msg.sender);
        (uint256 lockDate, uint256 frozenTokens) = getFreezing(msg.sender, 0);
        require(block.timestamp > lockDate, "minimum period not exceeded");

        uint256 freezingStart = getLatestFreezingStart(msg.sender);
        uint256 lockDays = SafeMath.div(SafeMath.sub(lockDate, freezingStart), secondsInDay);
        uint256 interestAmount = SafeMath.mul(SafeMath.div(frozenTokens, 1000), lockDays);

        _releaseOnce();
        mint(msg.sender, interestAmount);
    }

    function releaseFrozenTeam() public {
        require(hasRole(TEAM_ROLE, _msgSender()), "Must be executed from exchange");
        _releaseOnce();
    }

    function recordMintedTokens(uint256 hxyAmount) public {
        require(hasRole(EXCHANGE_ROLE, _msgSender()), "Must be executed from exchange");
        _recordMintedTokens(hxyAmount);
    }

    function mint(address account, uint256 amount) internal {
        _recordMintedTokens(amount);
        _mint(account, amount);
    }

    function mintAndFreezeTo(address _to, uint _amount, uint256 _until) internal {
        _recordMintedTokens(_amount);
        _mintAndFreezeTo(_to, _amount, _until);
    }

    function _recordMintedTokens(uint256 hxyAmount) internal {
        totalHxyMinted = SafeMath.add(totalHxyMinted, hxyAmount);

        if (currentHxyRound < maxHxyRounds) {
            if (totalHxyMinted + hxyAmount >= getRemainingHxyInRound()) {
                _incrementHxyRateRound();
            }
        }
    }

    function _mintForTeam(address _teamAddress, uint256 _teamLockPeriod) internal {
        _setupRole(TEAM_ROLE, _msgSender());
        teamAddress = _teamAddress;
        teamLockPeriod = _teamLockPeriod;
        _mintAndFreezeTo(teamAddress, teamSupply, teamLockPeriod);
    }

    function _incrementHxyRateRound() internal returns (bool) {
        currentHxyRound++;
        currentHxyRoundRate = SafeMath.mul(hxyRoundBaseRate[currentHxyRound], baseHexToHxyRate);
        return true;
    }

    function _daysToTimestamp(uint256 lockDays) internal view returns(uint256) {
        return SafeMath.add(block.timestamp, SafeMath.mul(lockDays, secondsInDay));
    }
}