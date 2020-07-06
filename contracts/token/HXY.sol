pragma solidity ^0.6.2;

import "./ERC20FreezableCapped.sol";

import "../base/HexMoneyTeam.sol";

import "../whitelist/WhitelistLib.sol";
import "../whitelist/HexWhitelist.sol";

contract HXY is ERC20FreezableCapped, HexMoneyTeam {
    using WhitelistLib for WhitelistLib.AllowedAddress;

    uint256 internal liquidSupply = 694866350105876;
    uint256 internal lockedSupply = SafeMath.mul(6, 10 ** 14);

    uint256 internal lockedSupplyFreezingStarted;

    address internal lockedSupplyAddress;
    address internal liquidSupplyAddress;

    struct LockedSupplyAddresses {
        address firstAddress;
        address secondAddress;
        address thirdAddress;
        address fourthAddress;
        address fifthAddress;
        address sixthAddress;
    }

    LockedSupplyAddresses internal lockedSupplyAddresses;
    bool internal lockedSupplyPreminted;

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



    //constructor(address payable _teamAddress,  address _liqSupAddress, address _lockSupAddress, address _migratedSupplyAddress)
    constructor(address _whitelistAddress,  address _liqSupAddress, uint256 _liqSupAmount)
    public
    ERC20FreezableCapped(SafeMath.mul(60,  10 ** 14))        // cap = 60,000,000
    ERC20("HEX Money", "HXY")
    {
        require(address(_whitelistAddress) != address(0x0), "whitelist address should not be empty");
        require(address(_liqSupAddress) != address(0x0), "liquid supply address should not be empty");
        _setupDecimals(8);

        _setupRole(DEPLOYER_ROLE, _msgSender());


        whitelist = HexWhitelist(_whitelistAddress);
        _premintLiquidSupply(_liqSupAddress, _liqSupAmount);
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

    function mintFromExchange(address account, uint256 amount) public {
        address executionAddress = _msgSender();
        require(whitelist.isRegisteredExchange(executionAddress), "must be executed from whitelisted dapp");
        whitelist.addToExchangeDailyLimit(executionAddress, amount);

        if (whitelist.getExchangeTradeable(executionAddress)) {
            mint(account, amount);
        } else {
            uint256 lockPeriod = whitelist.getExchangeLockPeriod(executionAddress);
            mintAndFreezeTo(account, amount, lockPeriod);
        }
    }

    function mintFromDappOrReferral(address account, uint256 amount) public {
        address executionAddress = _msgSender();
        require(whitelist.isRegisteredDappOrReferral(executionAddress), "must be executed from whitelisted address");
        if (whitelist.isRegisteredDapp(executionAddress)) {
            whitelist.addToDappDailyLimit(executionAddress, amount);
        } else {
            whitelist.addToReferralDailyLimit(executionAddress, amount);
        }

        if (whitelist.getDappTradeable(executionAddress)) {
            _mintDirectly(account, amount);
        } else {
            uint256 lockPeriod = whitelist.getDappOrReferralLockPeriod(executionAddress);
            _mintAndFreezeDirectly(account, amount, lockPeriod);
        }
    }

    function freezeHxy(uint256 lockAmount) public {
        freeze(_msgSender(), block.timestamp, lockAmount);
        totalFrozen = SafeMath.add(totalFrozen, lockAmount);
        totalCirculating = SafeMath.sub(totalCirculating, lockAmount);
    }

    function refreezeHxy(uint256 startDate) public {
        bytes32 freezeId = _toFreezeKey(_msgSender(), startDate);
        

        uint256 frozenTokens = freezingAmounts[freezeId];
        uint256 interestDays = SafeMath.div(SafeMath.sub(block.timestamp, startDate), SECONDS_IN_DAY);
        uint256 interestAmount = SafeMath.mul(SafeMath.div(frozenTokens, 1000), interestDays);

        refreeze(_msgSender(), startDate, interestAmount);
        totalFrozen = SafeMath.add(totalFrozen, interestAmount);
    }

    function releaseFrozen(uint256 _startDate) public {
        bytes32 freezeId = _toFreezeKey(_msgSender(), _startDate);

        uint256 frozenTokens = freezingAmounts[freezeId];

        release(_msgSender(), _startDate);

        if (!_isLockedAddress()) {
            uint256 interestDays = SafeMath.div(SafeMath.sub(block.timestamp, _startDate), SECONDS_IN_DAY);
            uint256 interestAmount = SafeMath.mul(SafeMath.div(frozenTokens, 1000), interestDays);
            _mint(_msgSender(), interestAmount);

            totalFrozen = SafeMath.sub(totalFrozen, frozenTokens);
            totalCirculating = SafeMath.add(totalCirculating, frozenTokens);
            totalPayedInterest = SafeMath.add(totalPayedInterest, interestAmount);
        }
    }

    function mint(address _to, uint256 _amount) internal {
        _preprocessMint(_to, _amount);
    }

    function mintAndFreezeTo(address _to, uint _amount, uint256 _lockDays) internal {
        _preprocessMintWithFreeze(_to, _amount, _lockDays);
    }

    function _premintLiquidSupply(address _liqSupAddress, uint256 _liqSupAmount) internal {
        require(_liqSupAddress != address(0x0), "liquid supply address cannot be zero");
        require(_liqSupAmount != 0, "liquid supply amount cannot be zero");
        liquidSupplyAddress = _liqSupAddress;
        liquidSupply = _liqSupAmount;
        _mint(_liqSupAddress, _liqSupAmount);
    }

    function premintLocked(address[6] memory _lockSupAddresses,  uint256[10] memory _unlockDates) public {
        require(hasRole(DEPLOYER_ROLE, _msgSender()), "Must have deployer role");
        require(!lockedSupplyPreminted, "cannot premint locked twice");
        _premintLockedSupply(_lockSupAddresses, _unlockDates);
    }

    function _premintLockedSupply(address[6] memory _lockSupAddresses, uint256[10] memory _unlockDates) internal {

        lockedSupplyAddresses.firstAddress = _lockSupAddresses[0];
        lockedSupplyAddresses.secondAddress = _lockSupAddresses[1];
        lockedSupplyAddresses.thirdAddress = _lockSupAddresses[2];
        lockedSupplyAddresses.fourthAddress = _lockSupAddresses[3];
        lockedSupplyAddresses.fifthAddress = _lockSupAddresses[4];
        lockedSupplyAddresses.sixthAddress = _lockSupAddresses[4];

        for (uint256 i = 0; i < 10; i++) {
            uint256 startDate = SafeMath.add(block.timestamp, SafeMath.add(i, 5));

            uint256 endFreezeDate = _unlockDates[i];
            uint256 lockSeconds = SafeMath.sub(endFreezeDate, startDate);
            uint256 lockDays = SafeMath.div(lockSeconds, SECONDS_IN_DAY);


            uint256 firstSecondAmount = SafeMath.mul(180000, 10 ** uint256(decimals()));
            uint256 thirdAmount = SafeMath.mul(120000, 10 ** uint256(decimals()));
            uint256 fourthAmount = SafeMath.mul(90000, 10 ** uint256(decimals()));
            uint256 fifthSixthAmount = SafeMath.mul(15000, 10 ** uint256(decimals()));

            mintAndFreeze(lockedSupplyAddresses.firstAddress, startDate, lockDays, firstSecondAmount);
            mintAndFreeze(lockedSupplyAddresses.secondAddress, startDate, lockDays, firstSecondAmount);
            mintAndFreeze(lockedSupplyAddresses.thirdAddress, startDate, lockDays, thirdAmount);
            mintAndFreeze(lockedSupplyAddresses.fourthAddress, startDate, lockDays, fourthAmount);
            mintAndFreeze(lockedSupplyAddresses.fifthAddress, startDate, lockDays, fifthSixthAmount);
            mintAndFreeze(lockedSupplyAddresses.sixthAddress, startDate, lockDays, fifthSixthAmount);
        }

        lockedSupplyPreminted = true;
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

    function _mintDirectly(address _account, uint256 _hxyAmount) internal {
        _mint(_account, _hxyAmount);
    }

    function _mintAndFreezeDirectly(address _account, uint256 _hxyAmount, uint256 _freezeDays) internal {
        mintAndFreeze(_account, block.timestamp, _freezeDays, _hxyAmount);
    }

    function _isLockedAddress() internal view returns (bool) {
        if (_msgSender() == lockedSupplyAddresses.firstAddress) {
            return true;
        } else if (_msgSender() == lockedSupplyAddresses.secondAddress) {
            return true;
        } else if (_msgSender() == lockedSupplyAddresses.thirdAddress) {
            return true;
        } else if (_msgSender() == lockedSupplyAddresses.fourthAddress) {
            return true;
        } else if (_msgSender() == lockedSupplyAddresses.fifthAddress) {
            return true;
        } else if (_msgSender() == lockedSupplyAddresses.sixthAddress) {
            return true;
        } else {
            return false;
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

    function _toDecimals(uint256 amount) internal view returns (uint256) {
        return SafeMath.mul(amount, 10 ** uint256(decimals()));
    }
}