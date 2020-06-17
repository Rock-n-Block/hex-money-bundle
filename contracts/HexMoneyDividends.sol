pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./base/HexMoneyTeam.sol";
import "./base/HexMoneyInternal.sol";

import "./token/HXY.sol";

contract HexMoneyDividends is HexMoneyInternal {
    HXY internal hxyToken;
    IERC20 internal hexToken;
    IERC20 internal usdcToken;

    address payable internal firstTeamAddress;
    address payable internal secondTeamAddress;
    address payable internal thirdTeamAddress;
    //address payable fourthTeamAddress;

    struct CurrencyDividends {
        uint256 beforePrevDayTotal;    // before previous day tokens - for calculating gains on total yesterday
        uint256 prevDayTotal;          // previous day tokens (total recorded amount)
        uint256 todayReceived;         // current day tokens (total recorded amount)
        uint256 todayForClaim;         // total amount for claim - 90% from total of previous day)
        uint256 todayForTeamOne;       // distributed on beginning of day (10% from total of previous day)
        uint256 todayForTeamTwo;       // distributed on beginning of day (unclaimed amount from amount to claim in prev day)
        uint256 todayClaimed;          // total amount of claimed today
    }

    CurrencyDividends internal hexDividends;
    CurrencyDividends internal hxyDividends;
    CurrencyDividends internal ethDividends;
    CurrencyDividends internal usdcDividends;

    uint256 internal dividendsPercentage = 90;

    bool internal _initialRecordTimeSet;

    uint256 internal totalFrozenHxyToday;
    uint256 internal dividendsRecordTime;
    uint256 internal deployedAt;


    mapping(address => uint256) internal userClaimedLastTime;


    constructor (
        HXY _hxyToken,
        IERC20 _hexToken,
        IERC20 _usdcToken,
        address payable _teamAddress,
        address payable _secondTeamAddress,
        address payable _thirdTeamAddress,
        uint256 _initialRecordTime
    )
        public
    {
        require(address(_hxyToken) != address(0x0), "hxy token address should not be empty");
        require(address(_hexToken) != address(0x0), "hex token address should not be empty");
        require(address(_usdcToken) != address(0x0), "hex token address should not be empty");
        require(address(_teamAddress) != address(0x0), "team address should not be empty");
        require(address(_secondTeamAddress) != address(0x0), "team address should not be empty");
        hxyToken = _hxyToken;
        hexToken = _hexToken;
        usdcToken = _usdcToken;


        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        firstTeamAddress = _teamAddress;
        secondTeamAddress = _secondTeamAddress;
        thirdTeamAddress = _thirdTeamAddress;

        //dividendsRecordTime = SafeMath.add(block.timestamp, SafeMath.mul(1, SECONDS_IN_DAY));
        dividendsRecordTime = _initialRecordTime;
        totalFrozenHxyToday = HXY(hxyToken).getTotalFrozen();

        deployedAt = block.timestamp;
    }


    function getTodayDividendsTotal() public view returns (uint256[4] memory) {
        return [
            ethDividends.todayReceived,
            hxyDividends.todayReceived,
            hexDividends.todayReceived,
            usdcDividends.todayReceived
        ];
    }

    function getBeforePreviousDividendsTotal() public view returns (uint256[4] memory) {
        return [
            ethDividends.beforePrevDayTotal,
            hxyDividends.beforePrevDayTotal,
            hexDividends.beforePrevDayTotal,
            usdcDividends.beforePrevDayTotal
        ];
    }

    function getPreviousDividendsTotal() public view returns (uint256[4] memory) {
        return [
            ethDividends.prevDayTotal,
            hxyDividends.prevDayTotal,
            hexDividends.prevDayTotal,
            usdcDividends.prevDayTotal
        ];
    }

    function getAvailableDividends(address account) public view returns(uint256[4] memory) {
        uint256 userFrozenBalance = HXY(hxyToken).freezingBalanceOf(account);

        uint256 ethAmount;
        uint256 hxyAmount;
        uint256 hexAmount;
        uint256 usdcAmount;

        if (userFrozenBalance > 0) {
            ethAmount = getClaimAmount(ethDividends.todayForClaim, userFrozenBalance);
            hxyAmount = getClaimAmount(hxyDividends.todayForClaim, userFrozenBalance);
            hexAmount = getClaimAmount(hexDividends.todayForClaim, userFrozenBalance);
            usdcAmount = getClaimAmount(usdcDividends.todayForClaim, userFrozenBalance);
        }
        return [ethAmount, hxyAmount, hexAmount, usdcAmount];
    }

    function getUserLastClaim(address account) public view returns(uint256) {
        return userClaimedLastTime[account];
    }

    function getAvailableDividendsTotal() public view returns (uint256[4] memory ) {
        return [
            ethDividends.todayForClaim,
            hxyDividends.todayForClaim,
            hexDividends.todayForClaim,
            usdcDividends.todayForClaim
        ];

    }

    function getClaimedDividendsTotal() public view returns (uint256[4] memory ){
        return [
            ethDividends.todayClaimed,
            hxyDividends.todayClaimed,
            hexDividends.todayClaimed,
            usdcDividends.todayClaimed
        ];

    }

    function getRecordTime() public view returns (uint256) {
        return dividendsRecordTime;

    }

    function getDividendsPercentage() public view returns (uint256) {
        return dividendsPercentage;
    }

    function getHexTokenAddress() public view returns (address) {
        return address(hexToken);
    }

    function getHxyTokenAddress() public view returns (address) {
        return address(hxyToken);
    }

    function getUsdcTokenAddress() public view returns (address) {
        return address(usdcToken);
    }

    receive() external payable {
        updateAndSendDividends();
        ethDividends.todayReceived = SafeMath.add(ethDividends.todayReceived, msg.value);
    }

    function recordDividendsETH() external payable nonReentrant {
        require(msg.value != 0, "value must be supplied in call to record dividends");

        updateAndSendDividends();
        ethDividends.todayReceived = SafeMath.add(ethDividends.todayReceived, msg.value);
    }

    function recordDividendsHEX(uint256 amount) external nonReentrant {
        _recordDividendsErc20(address(hexToken), hexDividends, amount);

    }

    function recordDividendsHXY(uint256 amount) external nonReentrant {
        _recordDividendsErc20(address(hxyToken), hxyDividends, amount);
    }

    function recordDividendsUSDC(uint256 amount) external nonReentrant {
        _recordDividendsErc20(address(usdcToken), usdcDividends, amount);
    }


    function claimDividends() external nonReentrant {
        updateAndSendDividends();

        uint256 userFrozenBalance = HXY(hxyToken).freezingBalanceOf(_msgSender());
        uint256 userLastFreeze = HXY(hxyToken).latestFreezeTimeOf(_msgSender());
        require(userFrozenBalance != 0, "must be freezed amount of HXY to claim dividends");
        uint256 timeOfPrevDay = SafeMath.sub(dividendsRecordTime, (SafeMath.mul(1, SECONDS_IN_DAY)));
        require(userLastFreeze < timeOfPrevDay, "cannot claim if freezed today");
        require(userClaimedLastTime[_msgSender()] < timeOfPrevDay, "tokens already claimed today");

        processClaimHex(userFrozenBalance);
        processClaimHxy(userFrozenBalance);
        processClaimUsdc(userFrozenBalance);
        processClaimEth(userFrozenBalance);

        userClaimedLastTime[_msgSender()] = block.timestamp;

    }

    function _setInitialRecordTime(uint256 _recordTime) internal {
        dividendsRecordTime = _recordTime;
    }

    function _recordDividendsErc20(address erc20token, CurrencyDividends storage currencyDividends, uint256 amount) internal {
        require(IERC20(erc20token).allowance(_msgSender(), address(this)) >= amount, "amount to record is not available to transfer");
        require(IERC20(erc20token).transferFrom(_msgSender(), address(this), amount), "cannot transfer amount from sender");

        updateAndSendDividends();
        currencyDividends.todayReceived = SafeMath.add(currencyDividends.todayReceived, amount);
    }

    function getClaimAmount(uint256 todayForClaim, uint256 userFrozen) internal view returns (uint256){
        return SafeMath.div(SafeMath.mul(todayForClaim, userFrozen), totalFrozenHxyToday);
    }

    function processClaimEth(uint256 userFrozen) internal {
        if (ethDividends.todayForClaim > 0) {

            //uint256 amount = SafeMath.div(SafeMath.mul(ethDividends.todayForClaim, userFrozen), totalFrozenHxyToday);
            uint256 amount = getClaimAmount(ethDividends.todayForClaim, userFrozen);
            _msgSender().transfer(amount);
            ethDividends.todayClaimed = SafeMath.add(ethDividends.todayClaimed, amount);
        }
    }

    function _processClaimErc20(address erc20token, CurrencyDividends storage currencyDividends, uint256 userFrozen) internal {
        if (currencyDividends.todayForClaim > 0) {

            //uint256 amount = SafeMath.div(SafeMath.mul(currencyDividends.todayForClaim, userFrozen), totalFrozenHxyToday);
            uint256 amount = getClaimAmount(currencyDividends.todayForClaim, userFrozen);
            require(IERC20(erc20token).transfer(_msgSender(), amount), "fail in transfer HEX dividends");
            currencyDividends.todayClaimed = SafeMath.add(currencyDividends.todayClaimed, amount);
        }
    }

    function processClaimHex(uint256 userFrozen) internal {
        _processClaimErc20(address(hexToken), hexDividends, userFrozen);
    }

    function processClaimHxy(uint256 userFrozen) internal {
        _processClaimErc20(address(hxyToken), hxyDividends, userFrozen);
    }

    function processClaimUsdc(uint256 userFrozen) internal {
        _processClaimErc20(address(usdcToken), usdcDividends, userFrozen);
    }


    function isNewDayStarted() internal view returns (bool) {
        return block.timestamp > dividendsRecordTime ? true : false;
    }

    function isInitialDeployTime() internal view returns (bool) {
        return block.timestamp < SafeMath.add(deployedAt, SafeMath.mul(1, SECONDS_IN_DAY));
    }


    function _updateDividends(CurrencyDividends storage currencyDividends) internal {
        // amount of tokens available for claiming today
        uint256 userTokensToClaim = SafeMath.div(SafeMath.mul(currencyDividends.todayReceived, dividendsPercentage), 100);

        // amount of tokens distributed for team one
        currencyDividends.todayForTeamOne = SafeMath.sub(currencyDividends.todayReceived, userTokensToClaim);

        // amount of tokens distributed for team two
        uint256 tokensToTeamTwo;
        if (currencyDividends.todayForClaim > currencyDividends.todayClaimed) {
            tokensToTeamTwo = SafeMath.sub(currencyDividends.todayForClaim, currencyDividends.todayClaimed);
        }

        currencyDividends.todayForTeamTwo = tokensToTeamTwo;

        // resetting new amount of  claimable tokens for today
        currencyDividends.todayForClaim = userTokensToClaim;

        // moving total recorded amount to previous days, resetting amounts for today
        currencyDividends.todayClaimed = 0;
        currencyDividends.beforePrevDayTotal = currencyDividends.prevDayTotal;
        currencyDividends.prevDayTotal = currencyDividends.todayReceived;
        currencyDividends.todayReceived = 0;
    }

    function getTeamAmountCurrency(CurrencyDividends storage currencyDividends, bool _haveUnclaimed)
        internal
        view
        returns (uint256[3] memory amounts)
    {
        uint256 firstAddressAmount = currencyDividends.todayForTeamOne;

        uint256 secondAddressAmount;
        uint256 thirdAddressAmount;
        if (_haveUnclaimed) {
            secondAddressAmount = SafeMath.div(SafeMath.mul(currencyDividends.todayForTeamTwo, 60), 100);
            thirdAddressAmount = SafeMath.sub(currencyDividends.todayForTeamTwo, secondAddressAmount);
        }

        amounts = [firstAddressAmount, secondAddressAmount, thirdAddressAmount];
    }

    function transferTeamEth() internal {
        bool haveUnclaimed = ethDividends.todayForTeamTwo > 0 ? true : false;

        uint256[3] memory teamAmounts = getTeamAmountCurrency(ethDividends, haveUnclaimed);

        firstTeamAddress.transfer(teamAmounts[0]);

        if (haveUnclaimed) {
            secondTeamAddress.transfer(teamAmounts[1]);
            thirdTeamAddress.transfer(teamAmounts[2]);
        }
    }

    function _transferTeamErc20(address erc20token, CurrencyDividends storage currencyDividends) internal {
        bool haveUnclaimed = currencyDividends.todayForTeamTwo > 0 ? true : false;

        uint256[3] memory teamAmounts = getTeamAmountCurrency(currencyDividends, haveUnclaimed);

        if (currencyDividends.todayForTeamOne > 0) {
            IERC20(erc20token).transfer(firstTeamAddress, teamAmounts[0]);
        }

        if (haveUnclaimed) {
            IERC20(erc20token).transfer(secondTeamAddress, teamAmounts[1]);
            IERC20(erc20token).transfer(thirdTeamAddress, teamAmounts[2]);
        }
    }

    function transferTeamHex() internal {
        _transferTeamErc20(address(hexToken), hexDividends);
    }

    function transferTeamHxy() internal {
        _transferTeamErc20(address(hxyToken), hxyDividends);
    }

    function transfertTeamUsdc() internal {
        _transferTeamErc20(address(usdcToken), usdcDividends);
    }

    function transferTeamAllCurrencies() internal {
        transferTeamEth();
        transferTeamHxy();
        transferTeamHex();
        transfertTeamUsdc();
    }

    function updateDividendsForAllCurrencies() internal {
        _updateDividends(ethDividends);
        _updateDividends(hxyDividends);
        _updateDividends(hexDividends);
        _updateDividends(usdcDividends);

        uint256 timeAfterRecord = SafeMath.sub(block.timestamp, dividendsRecordTime);
        uint256 daysPassed = timeAfterRecord > SECONDS_IN_DAY ? SafeMath.div(timeAfterRecord, SECONDS_IN_DAY) : 0;
        dividendsRecordTime = SafeMath.add(dividendsRecordTime, SafeMath.mul(SafeMath.add(daysPassed, 1), SECONDS_IN_DAY));

        totalFrozenHxyToday = HXY(hxyToken).getTotalFrozen();
    }

    function updateAndSendDividends() internal {
        if (isNewDayStarted()) {
            updateDividendsForAllCurrencies();
            transferTeamAllCurrencies();
        }
    }


}
