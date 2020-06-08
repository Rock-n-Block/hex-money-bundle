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
    uint256 internal teamFreezeStart;

    uint256 internal liquidSupply = SafeMath.mul(6, 10 ** 14);
    uint256 internal lockedSupply = SafeMath.mul(6, 10 ** 14);
    uint256 internal migratedSupply = SafeMath.mul(750, 10 ** 11);

    uint256 internal lockedSupplyFreezingStarted;

    address internal lockedSupplyAddress;
    address internal liquidSupplyAddress;

    // total amounts variables
    uint256 internal totalMinted;
    uint256 internal totalFrozen;
    uint256 internal totalCirculating;
    uint256 internal totalPayedInterest;

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

    function getTotalPayedInterest() public view returns (uint256) {
        return totalPayedInterest;
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


    function getCurrentInterestAmount(address _addr, uint256 _freezeStartDate) public view returns (uint256) {
        bytes32 freezeId = _toFreezeKey(_addr, _freezeStartDate);
        Freezing memory userFreeze = freezings[freezeId];

        uint256 frozenTokens = userFreeze.freezeAmount;
        if (frozenTokens != 0) {
            uint256 startFreezeDate = userFreeze.startDate;
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
            mintAndFreezeTo(account, amount, lockPeriod);
        }
    }

    function mintFromReferral(address account, uint256 amount) public {
        address referralAddress = _msgSender();
        require(whitelist.isRegisteredReferral(referralAddress), "must be executed from whitelisted referral");

        if (whitelist.getReferralTradeable(referralAddress)) {
            mint(account, amount);
        } else {
            uint256 lockPeriod = whitelist.getReferralLockPeriod(referralAddress);
            mintAndFreezeTo(account, amount, lockPeriod);
        }
    }

    function freezeHxy(uint256 lockAmount) public {
        freeze(_msgSender(), block.timestamp, MINIMAL_FREEZE_PERIOD, lockAmount);
        totalFrozen = SafeMath.add(totalFrozen, lockAmount);
        totalCirculating = SafeMath.sub(totalCirculating, lockAmount);
    }

    function refreezeHxy(uint256 startDate) public {
        bytes32 freezeId = _toFreezeKey(_msgSender(), startDate);
        Freezing memory userFreezing = freezings[freezeId];

        uint256 frozenTokens = userFreezing.freezeAmount;
        uint256 interestDays = SafeMath.div(SafeMath.sub(block.timestamp, userFreezing.startDate), SECONDS_IN_DAY);
        uint256 interestAmount = SafeMath.mul(SafeMath.div(frozenTokens, 1000), interestDays);

        refreeze(startDate, interestAmount);
    }

    function releaseFrozen(uint256 _startDate) public {
        require(!hasRole(TEAM_ROLE, _msgSender()), "Cannot be released from team account");
        require(_msgSender() != lockedSupplyAddress, "Cannot be released from locked supply address");

        bytes32 freezeId = _toFreezeKey(_msgSender(), _startDate);
        Freezing memory userFreezing = freezings[freezeId];

        uint256 frozenTokens = userFreezing.freezeAmount;
        uint256 interestDays = SafeMath.div(SafeMath.sub(block.timestamp, userFreezing.startDate), SECONDS_IN_DAY);
        uint256 interestAmount = SafeMath.mul(SafeMath.div(frozenTokens, 1000), interestDays);

        release(_startDate);
        mint(_msgSender(), interestAmount);


        totalFrozen = SafeMath.sub(totalFrozen, frozenTokens);
        totalCirculating = SafeMath.add(totalCirculating, frozenTokens);
        totalPayedInterest = SafeMath.add(totalPayedInterest, interestAmount);
    }

    function releaseFrozenTeam() public onlyTeamRole {
        release(teamFreezeStart);
    }

    function releaseLockedSupply() public {
        require(_msgSender() == lockedSupplyAddress, "Only for releasing locked supply");
        release(lockedSupplyFreezingStarted);
    }

    function mint(address _to, uint256 _amount) internal {
        _preprocessMint(_to, _amount);
    }

    function mintAndFreezeTo(address _to, uint _amount, uint256 _lockDays) internal {
        _preprocessMintWithFreeze(_to, _amount, _lockDays);
    }

    function _premintForTeam(address payable _teamAddress, uint256 _teamLockPeriod) internal {
        require(_teamAddress != address(0x0), "team address cannot be zero");
        require(_teamLockPeriod > 0, "team lock period cannot be zero");
        _setupRole(TEAM_ROLE, _teamAddress);
        teamAddress = _teamAddress;
        teamLockPeriod = _teamLockPeriod;
        mintAndFreeze(teamAddress, block.timestamp, _teamLockPeriod, teamSupply);
    }

    function _premintLiquidSupply(address _liqSupAddress) internal {
        require(_liqSupAddress != address(0x0), "liquid supply address cannot be zero");
        _mint(_liqSupAddress, liquidSupply);
    }

    function _premintLockedSupply(address _lockSupAddress) internal {
        require(_lockSupAddress != address(0x0), "liquid supply address cannot be zero");
        lockedSupplyAddress = _lockSupAddress;

        mintAndFreeze(_lockSupAddress, block.timestamp, 365, lockedSupply);

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

    function _preprocessMintWithFreeze(address _account, uint256 _hexAmount, uint256 _freezeDays) internal {
        uint256 currentRoundHxyAmount = SafeMath.div(_hexAmount, currentHxyRoundRate);
        if (currentRoundHxyAmount < getRemainingHxyInRound()) {
            uint256 hxyAmount = currentRoundHxyAmount;
            totalMinted = SafeMath.add(totalMinted, hxyAmount);
            mintAndFreeze(_account, block.timestamp, _freezeDays, hxyAmount);
        } else if (currentRoundHxyAmount == getRemainingHxyInRound()) {
            uint256 hxyAmount = currentRoundHxyAmount;
            mintAndFreeze(_account, block.timestamp, _freezeDays, hxyAmount);

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
            mintAndFreeze(_account, block.timestamp, _freezeDays, hxyAmount);
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