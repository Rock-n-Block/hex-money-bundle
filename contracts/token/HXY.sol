pragma solidity ^0.6.2;

import "./ERC20FreezableCapped.sol";

import "../base/HexMoneyTeam.sol";

import "../whitelist/WhitelistLib.sol";
import "../whitelist/HexWhitelist.sol";

contract HXY is ERC20FreezableCapped, HexMoneyTeam {

    using WhitelistLib for WhitelistLib.AllowedAddress;

    // latest freezing info for user
    struct latestFreezing {
        uint256 startDate;
        uint256 lockDays;
        uint256 tokenAmount;
    }

    mapping (address => latestFreezing) internal latestFreezingData;

    // premint amounts
    uint256 internal teamLockPeriod;
    uint256 internal teamSupply = SafeMath.mul(12, 10 ** 14);

    uint256 internal liquidSupply = SafeMath.mul(6, 10 ** 14);
    uint256 internal lockedSupply = SafeMath.mul(6, 10 ** 14);
    uint256 internal migratedSupply = SafeMath.mul(750, 10 ** 11);

    uint256[10] internal lockedSupplyDays;
    bool[10] internal lockedSupplyPackClaimed;
    uint256 internal lockedSupplyFreezingStarted;

    address internal lockedSupplyAddress;
    address internal liquidSupplyAddress;

    // total amounts variables
    uint256 internal totalMinted;
    uint256 internal totalFrozen;
    uint256 internal totalCirculating;

    // round logic structures
    uint256 internal hxyMintedMultiplier = 10 ** 6;
    uint256[] internal hxyRoundMintAmount = [3, 6, 9, 12, 15, 18, 21, 24, 27];
    uint256 internal baseHexToHxyRate = 10 ** 3;
    uint256[] internal hxyRoundBaseRate = [2, 3, 4, 5, 6, 7, 8, 9, 10];

    uint256 internal maxHxyRounds = 9;

    // initial round
    uint256 internal currentHxyRound;
    uint256 internal currentHxyRoundRate = SafeMath.mul(hxyRoundBaseRate[0], baseHexToHxyRate);



    constructor(address payable _teamAddress,  address _liqSupAddress, address _lockSupAddress, address _migratedSupplyAddress)
    ERC20FreezableCapped(SafeMath.mul(60,  10 ** 14))        // cap = 60,000,000
    ERC20("HXY", "HXY")
    public
    {
        _setupDecimals(8);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _premintForTeam(_teamAddress, 365);
        _premintLiquidSupply(_liqSupAddress);
        _premintLockedSupply(_lockSupAddress);
        _premintMigratedSupply(_migratedSupplyAddress);
    }

    function getRemainingHxyInRound() public view returns (uint256) {
        return _getRemainingHxyInRound(currentHxyRound);
    }

    function getTotalHxyInRound() public view returns (uint256) {
        return _getTotalHxyInRound(currentHxyRound);
    }

    function getTotalHxyMinted() public view returns (uint256) {
        return totalMinted;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return totalCirculating;
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

    function getLockedSupply() public view returns (uint256) {
        return freezingBalanceOf(lockedSupplyAddress);
    }

    function getLockedSupplyAddress() public view returns (address) {
        return lockedSupplyAddress;
    }

    function getLatestFreezingData(address _addr) public view returns (uint256, uint256, uint256) {
        latestFreezing memory data = latestFreezingData[_addr];
        return (data.startDate, data.lockDays, data.tokenAmount);
    }

    function getCurrentInterestAmount(address _addr) public view returns (uint256) {
        uint256 frozenTokens = latestFreezingData[_addr].tokenAmount;
        if (frozenTokens != 0) {
            uint256 startFreezeDate = latestFreezingData[_addr].startDate;
            uint256 interestDays = SafeMath.div(SafeMath.sub(block.timestamp, startFreezeDate), SECONDS_IN_DAY);
            return SafeMath.mul(SafeMath.div(frozenTokens, 1000), interestDays);
        } else {
            return 0;
        }
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
        }
    }

    function mintFromReferral(address account, uint256 amount) public {
        address referralAddress = _msgSender();
        require(whitelist.isRegisteredReferral(referralAddress), "must be executed from whitelisted referral");

        if (whitelist.getReferralTradeable(referralAddress)) {
            mint(account, amount);
        } else {
            uint256 lockPeriod = whitelist.getReferralLockPeriod(referralAddress);
            uint256 freezeUntil = _daysToTimestamp(lockPeriod);
            mintAndFreezeTo(account, amount, freezeUntil);
        }
    }

    function freezeHxy(uint256 lockAmount) public {
        uint256 startFreezeDate = latestFreezingData[_msgSender()].startDate;
        if (startFreezeDate != 0) {
            uint256 lockDate = _daysToTimestampFrom(startFreezeDate, MINIMAL_FREEZE_PERIOD);
            if (block.timestamp >= lockDate) {
                releaseFrozen();
            }
        }

        _freezeTo(_msgSender(), lockAmount, uint256(block.timestamp));
        _setNewFreezeData(_msgSender(), block.timestamp, MINIMAL_FREEZE_PERIOD, lockAmount);
        totalFrozen = SafeMath.add(totalFrozen, lockAmount);
        totalCirculating = SafeMath.sub(totalCirculating, lockAmount);
    }

    function releaseFrozen() public {
        require(!hasRole(TEAM_ROLE, _msgSender()), "Cannot be released from team account");
        require(_msgSender() != lockedSupplyAddress, "Cannot be released from locked supply address");

        uint256 startFreezeDate = latestFreezingData[_msgSender()].startDate;
        uint256 lockDate = _daysToTimestampFrom(startFreezeDate, MINIMAL_FREEZE_PERIOD);
        require(block.timestamp > lockDate, "minimum period not exceeded");

        uint256 interestDays = SafeMath.div(SafeMath.sub(block.timestamp, startFreezeDate), SECONDS_IN_DAY);

        uint256 frozenTokens = latestFreezingData[_msgSender()].tokenAmount;
        uint256 interestAmount = SafeMath.mul(SafeMath.div(frozenTokens, 1000), interestDays);

        uint256 timeLock = latestFreezingData[_msgSender()].lockDays;
        _releaseOnce(timeLock);

        _setNewFreezeData(_msgSender(), 0, 0, 0);
        mint(_msgSender(), interestAmount);


        totalFrozen = SafeMath.sub(totalFrozen, frozenTokens);
        totalCirculating = SafeMath.add(totalCirculating, frozenTokens);
    }

    function releaseFrozenTeam() public onlyTeamRole {
        _releaseOnce(365);
    }

    function releaseLockedSupply() public {
        require(_msgSender() == lockedSupplyAddress, "Only for releasing locked supply");

        for (uint256 i = 0; i < 10; i++) {
            if (!lockedSupplyPackClaimed[i]) {
                uint256 packDays = lockedSupplyDays[i];
                if (block.timestamp > _daysToTimestampFrom(lockedSupplyFreezingStarted, packDays)) {
                    _releaseOnce(packDays);
                    lockedSupplyPackClaimed[i] = true;
                }
            }
        }
    }

    function mint(address _to, uint256 _amount) internal {
        _preprocessMint(_to, _amount);
    }

    function mintAndFreezeTo(address _to, uint _amount, uint256 _lockDays) internal {
        _preprocessMintWithFreeze(_to, _amount);
        //_mintAndFreezeTo(_to, _amount, _until);
        _setNewFreezeData(_msgSender(), block.timestamp, _lockDays, _amount);
    }

    function _premintForTeam(address payable _teamAddress, uint256 _teamLockPeriod) internal {
        require(_teamAddress != address(0x0), "team address cannot be zero");
        require(_teamLockPeriod > 0, "team lock period cannot be zero");
        _setupRole(TEAM_ROLE, _teamAddress);
        teamAddress = _teamAddress;
        teamLockPeriod = _teamLockPeriod;
        //uint256 lockDays = _daysToTimestamp(teamLockPeriod);
        _mintAndFreezeTo(teamAddress, teamSupply, block.timestamp);
        _setNewFreezeData(_teamAddress, block.timestamp, _teamLockPeriod, teamSupply);
    }

    function _premintLiquidSupply(address _liqSupAddress) internal {
        require(_liqSupAddress != address(0x0), "liquid supply address cannot be zero");
        _mint(_liqSupAddress, liquidSupply);
    }

    function _premintLockedSupply(address _lockSupAddress) internal {
        require(_lockSupAddress != address(0x0), "liquid supply address cannot be zero");
        lockedSupplyAddress = _lockSupAddress;

        for (uint256 i = 0; i < 10; i++) {
            uint256 lockDays = SafeMath.mul(30, SafeMath.add(i, 1));
            _mintAndFreezeTo(_lockSupAddress, SafeMath.div(lockedSupply, 10), block.timestamp);
            lockedSupplyDays[i] = lockDays;
        }

        lockedSupplyFreezingStarted = block.timestamp;
    }

    function _premintMigratedSupply(address _migratedSupAddress) internal {
        require(_migratedSupAddress != address(0x0), "migrated supply address cannot be zero");
        _mint(_migratedSupAddress, migratedSupply);
    }


    function _preprocessMint(address _account, uint256 _hexAmount) internal {
        uint256 currentRoundHxyAmount = SafeMath.div(_hexAmount, currentHxyRoundRate);
        if (currentRoundHxyAmount < getRemainingHxyInRound()) {
            uint256 hxyAmount = currentRoundHxyAmount;
            _mint(_account, hxyAmount);

            totalMinted = SafeMath.add(totalMinted, hxyAmount);
            totalCirculating = SafeMath.add(totalCirculating, hxyAmount);
        } else if (currentRoundHxyAmount == getRemainingHxyInRound()) {
            uint256 hxyAmount = currentRoundHxyAmount;
            _mint(_account, hxyAmount);

            _incrementHxyRateRound();

            totalMinted = SafeMath.add(totalMinted, hxyAmount);
            totalCirculating = SafeMath.add(totalCirculating, hxyAmount);
        } else {
            uint256 hxyAmount;
            uint256 hexPaymentAmount;
            while (hexPaymentAmount < _hexAmount) {
                uint256 hxyRoundTotal = SafeMath.mul(_toDecimals(hxyRoundMintAmount[currentHxyRound]), hxyMintedMultiplier);

                uint256 hxyInCurrentRoundMax = SafeMath.sub(hxyRoundTotal, totalMinted);
                uint256 hexInCurrentRoundMax = SafeMath.mul(hxyInCurrentRoundMax, currentHxyRoundRate);

                uint256 hexInCurrentRound;
                uint256 hxyInCurrentRound;
                if (SafeMath.sub(_hexAmount, hexPaymentAmount) < hexInCurrentRoundMax) {
                    hexInCurrentRound = SafeMath.sub(_hexAmount, hexPaymentAmount);
                    hxyInCurrentRound = SafeMath.div(hexInCurrentRound, currentHxyRoundRate);
                } else {
                    hexInCurrentRound = hexInCurrentRoundMax;
                    hxyInCurrentRound = hxyInCurrentRoundMax;

                    _incrementHxyRateRound();
                }

                hxyAmount = SafeMath.add(hxyAmount, hxyInCurrentRound);
                hexPaymentAmount = SafeMath.add(hexPaymentAmount, hexInCurrentRound);

                totalMinted = SafeMath.add(totalMinted, hxyInCurrentRound);
                totalCirculating = SafeMath.add(totalCirculating, hxyAmount);
            }
            _mint(_account, hxyAmount);
        }
    }

    function _preprocessMintWithFreeze(address _account, uint256 _hexAmount) internal {
        uint256 currentRoundHxyAmount = SafeMath.div(_hexAmount, currentHxyRoundRate);
        if (currentRoundHxyAmount < getRemainingHxyInRound()) {
            uint256 hxyAmount = currentRoundHxyAmount;
            totalMinted = SafeMath.add(totalMinted, hxyAmount);
            _mintAndFreezeTo(_account, hxyAmount, uint256(block.timestamp));
        } else if (currentRoundHxyAmount == getRemainingHxyInRound()) {
            uint256 hxyAmount = currentRoundHxyAmount;
            _mintAndFreezeTo(_account, hxyAmount, uint256(block.timestamp));

            totalMinted = SafeMath.add(totalMinted, hxyAmount);

            _incrementHxyRateRound();
        } else {
            uint256 hxyAmount;
            uint256 hexPaymentAmount;
            while (hexPaymentAmount < _hexAmount) {
                uint256 hxyRoundTotal = SafeMath.mul(_toDecimals(hxyRoundMintAmount[currentHxyRound]), hxyMintedMultiplier);

                uint256 hxyInCurrentRoundMax = SafeMath.sub(hxyRoundTotal, totalMinted);
                uint256 hexInCurrentRoundMax = SafeMath.mul(hxyInCurrentRoundMax, currentHxyRoundRate);

                uint256 hexInCurrentRound;
                uint256 hxyInCurrentRound;
                if (SafeMath.sub(_hexAmount, hexPaymentAmount) < hexInCurrentRoundMax) {
                    hexInCurrentRound = SafeMath.sub(_hexAmount, hexPaymentAmount);
                    hxyInCurrentRound = SafeMath.div(hexInCurrentRound, currentHxyRoundRate);
                } else {
                    hexInCurrentRound = hexInCurrentRoundMax;
                    hxyInCurrentRound = hxyInCurrentRoundMax;

                    _incrementHxyRateRound();
                }

                hxyAmount = SafeMath.add(hxyAmount, hxyInCurrentRound);
                hexPaymentAmount = SafeMath.add(hexPaymentAmount, hexInCurrentRound);

                totalMinted = SafeMath.add(totalMinted, hxyInCurrentRound);
            }
            _mintAndFreezeTo(_account, hxyAmount, uint256(block.timestamp));
        }
    }

    function _getTotalHxyInRound(uint256 _round) public view returns (uint256) {
        return SafeMath.mul(_toDecimals(hxyRoundMintAmount[_round]),hxyMintedMultiplier);
    }

    function _getRemainingHxyInRound(uint256 _round) public view returns (uint256) {
        return SafeMath.sub(SafeMath.mul(_toDecimals(hxyRoundMintAmount[_round]), hxyMintedMultiplier), totalMinted);
    }

    function _incrementHxyRateRound() internal {
        currentHxyRound = SafeMath.add(currentHxyRound, 1);
        currentHxyRoundRate = SafeMath.mul(hxyRoundBaseRate[currentHxyRound], baseHexToHxyRate);
    }

    function _setNewFreezeData(address _to, uint256 _startDate, uint256 _lockDays, uint256 _tokenAmount) internal {
        latestFreezingData[_to].startDate = _startDate;
        latestFreezingData[_to].lockDays = _lockDays;
        latestFreezingData[_to].tokenAmount = _tokenAmount;
    }

    function _toDecimals(uint256 amount) internal view returns (uint256) {
        return SafeMath.mul(amount, 10 ** uint256(decimals()));
    }
}