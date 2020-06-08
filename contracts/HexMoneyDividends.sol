pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./base/HexMoneyTeam.sol";
import "./base/HexMoneyInternal.sol";

import "./token/HXY.sol";

contract HexMoneyDividends is HexMoneyTeam, HexMoneyInternal {
    IERC20 internal hexToken;
    HXY internal hxyToken;

    address payable secondTeamAddress;

    bool internal _initialRecordTimeSet;

    mapping (address => uint256) internal userClaimedHexDividends;
    mapping (address => uint256) internal lastHexClaim;

    uint256 internal hexDecimals = 10 ** 8;
    uint256 internal dividendsPercentage = 90;

    struct DividendsCurrency {
        uint256 teamTokens;
        uint256 previousDayTokens;
        uint256 claimedTodayTokens;
        uint256 currentDayTokens;
    }

    struct Dividends {
        DividendsCurrency hexDividends;
        DividendsCurrency hxyDividends;
        DividendsCurrency ethDividends;
        uint256 recordTime;
    }

    struct DividendsClaimed {
        uint256 hexAmount;
        uint256 hxyAmount;
        uint256 ethAmount;
    }

    struct DividendsUserClaimed {
        uint256 hexAmount;
        uint256 hxyAmount;
        uint256 ethAmount;
        uint256 lastClaim;
    }

    Dividends internal dividends;
    DividendsClaimed internal totalClaimedDividends;

    mapping(address => DividendsUserClaimed) internal userClaimedDividends;

    constructor (IERC20 newHexToken, HXY newHxyToken, address payable _teamAddress, address payable _secondTeamAddress) public {
        require(address(newHexToken) != address(0x0), "hex token address should not be empty");
        require(address(newHxyToken) != address(0x0), "hxy token address should not be empty");
        require(address(_teamAddress) != address(0x0), "team address should not be empty");
        require(address(_secondTeamAddress) != address(0x0), "team address should not be empty");
        hexToken = newHexToken;
        hxyToken = newHxyToken;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(TEAM_ROLE, _teamAddress);
        teamAddress = _teamAddress;
        secondTeamAddress = _secondTeamAddress;

        setDeployInitialRecordTime();
    }

    function getTodayDividends(address _addr) public view returns(uint256[3] memory) {
        uint256 userFrozenBalance = HXY(hxyToken).freezingBalanceOf(_addr);
        uint256 hexAmount;
        uint256 hxyAmount;
        uint256 ethAmount;

        if (userFrozenBalance != 0) {
            uint256 totalFrozen = HXY(hxyToken).getTotalFrozen();

            uint256 userFrozenPercentage = SafeMath.div(userFrozenBalance, totalFrozen);
            hexAmount = _getClaimAmount(dividends.hexDividends.currentDayTokens, userFrozenPercentage);
            hxyAmount = _getClaimAmount(dividends.hxyDividends.currentDayTokens, userFrozenPercentage);
            ethAmount = _getClaimAmount(dividends.ethDividends.currentDayTokens, userFrozenPercentage);
        }
        return [hexAmount, hxyAmount, ethAmount];
    }

    function getTodayDividendsTotal() public view returns (uint256[3] memory) {
        return [
            dividends.hexDividends.currentDayTokens,
            dividends.hxyDividends.currentDayTokens,
            dividends.ethDividends.currentDayTokens
        ];
    }

    function getAvailableDividends(address _addr) public view returns(uint256[3] memory) {
        uint256 userFrozenBalance = HXY(hxyToken).freezingBalanceOf(_addr);
        uint256 hexAmount;
        uint256 hxyAmount;
        uint256 ethAmount;

        if (userFrozenBalance != 0) {
            uint256 totalFrozen = HXY(hxyToken).getTotalFrozen();

            uint256 userFrozenPercentage = SafeMath.div(userFrozenBalance, totalFrozen);
            hexAmount = _getClaimAmount(dividends.hexDividends.previousDayTokens, userFrozenPercentage);
            hxyAmount = _getClaimAmount(dividends.hxyDividends.previousDayTokens, userFrozenPercentage);
            ethAmount = _getClaimAmount(dividends.ethDividends.previousDayTokens, userFrozenPercentage);
        }
        return [hexAmount, hxyAmount, ethAmount];
    }

    function getAvailableDividendsTotal() public view returns(uint256[3] memory) {
        return [
            dividends.hexDividends.previousDayTokens,
            dividends.hxyDividends.previousDayTokens,
            dividends.ethDividends.previousDayTokens
        ];

    }

    function getClaimedDividends(address _addr) public view returns (uint256[4] memory) {
        DividendsUserClaimed memory divs = userClaimedDividends[_addr];
        return [divs.hexAmount, divs.hxyAmount, divs.ethAmount, divs.lastClaim];
    }


    function getClaimedDividendsYesterday() public view returns (uint256[3] memory) {
        return [
            dividends.hexDividends.claimedTodayTokens,
            dividends.hxyDividends.claimedTodayTokens,
            dividends.ethDividends.claimedTodayTokens
        ];
    }

    function getClaimedDividendsTotal() public view returns (uint256[3] memory) {
        return [
            totalClaimedDividends.hexAmount,
            totalClaimedDividends.hxyAmount,
            totalClaimedDividends.ethAmount
        ];
    }

    function getRecordTime() public view returns (uint256) {
        return dividends.recordTime;
    }

    function getBlock() public view returns (uint256) {
        return block.timestamp;
    }

    function getRemainingRecordTime() public view returns (uint256) {
        if (block.timestamp < dividends.recordTime) {
            return SafeMath.sub(dividends.recordTime, block.timestamp);
        } else {
            uint256 daysPassed = SafeMath.div(SafeMath.sub(block.timestamp, dividends.recordTime), SECONDS_IN_DAY);
            daysPassed = (daysPassed < 1) ? 1 : daysPassed;

            uint256 adjustedRecordTime = SafeMath.add(dividends.recordTime, SafeMath.mul(daysPassed, SECONDS_IN_DAY));
            return SafeMath.sub(adjustedRecordTime, block.timestamp);
        }
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

    function recordDividendsHEX(uint256 amount) public {
        require(IERC20(hexToken).allowance(_msgSender(), address(this)) >= amount, "amount to record is not available to transfer");
        require(IERC20(hexToken).transferFrom(_msgSender(), address(this), amount), "cannot transfer amount from sender");

        _postprocessDividends(dividends.hexDividends, amount);
    }

    function recordDividendsHXY(uint256 amount) public {
        require(IERC20(hxyToken).allowance(_msgSender(), address(this)) >= amount, "amount to record is not available to transfer");
        require(IERC20(hxyToken).transferFrom(_msgSender(), address(this), amount), "cannot transfer amount from sender");

        _postprocessDividends(dividends.hxyDividends, amount);
    }

    receive() external payable {
         _postprocessDividends(dividends.ethDividends, msg.value);
    }

    function recordDividendsETH() public payable {
        require(msg.value != 0, "value must be supplied in call to record dividends");
        _postprocessDividends(dividends.ethDividends, msg.value);
    }

    function claimDividends() public {
        _checkUpdateDividendsAll();

        uint256 userFrozenBalance = HXY(hxyToken).freezingBalanceOf(_msgSender());
        require(userFrozenBalance != 0, "must be freezed amount of HXY to claim dividends");
        require(userClaimedDividends[_msgSender()].lastClaim <= dividends.recordTime, "tokens already claimed today");

        uint256 totalFrozen = HXY(hxyToken).getTotalFrozen();
        uint256 userFrozenPercentage = SafeMath.div(userFrozenBalance, totalFrozen);

        _processClaimHex(userFrozenPercentage);
        _processClaimHxy(userFrozenPercentage);
        _processClaimEth(userFrozenPercentage);

        userClaimedDividends[_msgSender()].lastClaim = block.timestamp;
    }

    function _processClaimHex(uint256 _userFrozenPercentage) internal {
        uint256 amount = _getClaimAmount(dividends.hexDividends.previousDayTokens, _userFrozenPercentage);

        if (amount != 0) {
            require(IERC20(hexToken).transfer(_msgSender(), amount), "fail in transfer HEX dividends");

            userClaimedDividends[_msgSender()].hexAmount = SafeMath.add(userClaimedDividends[_msgSender()].hexAmount, amount);
            totalClaimedDividends.hexAmount = SafeMath.add(totalClaimedDividends.hexAmount, amount);
            dividends.hexDividends.claimedTodayTokens = SafeMath.add(dividends.hexDividends.claimedTodayTokens, amount);
        }
    }

    function _processClaimHxy(uint256 _userFrozenPercentage) internal {
        uint256 amount = _getClaimAmount(dividends.hxyDividends.previousDayTokens, _userFrozenPercentage);

        if (amount != 0) {
            require(IERC20(hxyToken).transfer(_msgSender(), amount), "fail in transfer HXY dividends");

            userClaimedDividends[_msgSender()].hxyAmount = SafeMath.add(userClaimedDividends[_msgSender()].hxyAmount, amount);
            totalClaimedDividends.hxyAmount = SafeMath.add(totalClaimedDividends.hxyAmount, amount);
            dividends.hxyDividends.claimedTodayTokens = SafeMath.add(dividends.hxyDividends.claimedTodayTokens, amount);
        }
    }

    function _processClaimEth(uint256 _userFrozenPercentage) internal {
        uint256 amount = _getClaimAmount(dividends.ethDividends.previousDayTokens, _userFrozenPercentage);

        if (amount != 0) {
            _msgSender().transfer(amount);

            userClaimedDividends[_msgSender()].ethAmount = SafeMath.add(userClaimedDividends[_msgSender()].ethAmount, amount);
            totalClaimedDividends.ethAmount = SafeMath.add(totalClaimedDividends.ethAmount, amount);
            dividends.ethDividends.claimedTodayTokens = SafeMath.add(dividends.ethDividends.claimedTodayTokens, amount);
        }
    }

    function _getClaimAmount(uint256 currencyPrevDayAmount, uint256 userFrozenPercentage) internal view returns (uint256) {
        uint256 dailyDividendsAmount = SafeMath.div(SafeMath.mul(currencyPrevDayAmount, dividendsPercentage), 100);
        return SafeMath.mul(dailyDividendsAmount,userFrozenPercentage);
    }

    function manualCheckUpdateDividends() public {
        _checkUpdateDividendsAll();
    }

    function setHexToken(address newHexToken) public onlyAdminRole {
        require(newHexToken != address(0x0), "Invalid HEX token address");
        hexToken = ERC20(newHexToken);
    }

    function setHxyToken(address newHxyToken) public onlyAdminRole {
        require(newHxyToken != address(0x0), "Invalid HXY token address");
        hxyToken = HXY(newHxyToken);
    }

    function setDividendsPercent(uint256 newPercentage) public onlyAdminRole {
        require(newPercentage < 100, "invalid hex percentage");
        dividendsPercentage = newPercentage;
    }

    function setInitialRecordTime(uint256 recordTime) public onlyAdminRole {
        require(!_initialRecordTimeSet);
        _setInitialRecordTime(recordTime);

        _initialRecordTimeSet = true;
    }

    function setDeployInitialRecordTime() internal {
        dividends.recordTime = SafeMath.add(block.timestamp, SafeMath.mul(1, SECONDS_IN_DAY));
    }

    function _setInitialRecordTime(uint256 _recordTime) internal {
        dividends.recordTime = _recordTime;
    }

    function _postprocessDividends(DividendsCurrency storage currencyDividends, uint256 _amount) internal {
        _checkUpdateDividendsAll();
        currencyDividends.currentDayTokens = SafeMath.add(currencyDividends.currentDayTokens, _amount);
    }

    function _checkUpdateDividendsAll() internal {
        (uint256 teamAmountHex, bool haveUnclaimedHex) = _checkUpdateDividends(dividends.hexDividends);
        (uint256 teamAmountHxy, bool haveUnclaimedHxy) = _checkUpdateDividends(dividends.hxyDividends);
        (uint256 teamAmountEth, bool haveUnclaimedEth) = _checkUpdateDividends(dividends.ethDividends);

        if (teamAmountHex > 0) {
            _transferTeamHex(teamAmountHex, haveUnclaimedHex);
        }

        if (teamAmountHxy > 0) {
            _transferTeamHxy(teamAmountHxy, haveUnclaimedHxy);
        }

        if (teamAmountEth > 0) {
            _transferTeamEth(teamAmountEth, haveUnclaimedEth);
         }
    }

    function _checkUpdateDividends(DividendsCurrency storage currencyDividends) internal returns (uint256 teamAmount, bool haveUnclaimed) {
        if (block.timestamp > dividends.recordTime) {
            uint256 daysPassed = SafeMath.div(SafeMath.sub(block.timestamp, dividends.recordTime), SECONDS_IN_DAY);
            dividends.recordTime = SafeMath.add(dividends.recordTime, SafeMath.mul(daysPassed, SECONDS_IN_DAY));

            uint256 prevDayTokens;
            if (daysPassed <= 1) {
                prevDayTokens = currencyDividends.previousDayTokens;
                currencyDividends.previousDayTokens = currencyDividends.currentDayTokens;
            } else {
                prevDayTokens = SafeMath.add(currencyDividends.previousDayTokens, currencyDividends.currentDayTokens);
                currencyDividends.previousDayTokens = 0;
            }

            uint256 userDividendsAmount = SafeMath.div(SafeMath.mul(prevDayTokens, dividendsPercentage), 100);
            uint256 unclaimedAmount;
            if (currencyDividends.claimedTodayTokens < userDividendsAmount) {
                unclaimedAmount = SafeMath.sub(userDividendsAmount, currencyDividends.claimedTodayTokens);
                teamAmount = SafeMath.div(SafeMath.mul(unclaimedAmount, 80), 100);
                haveUnclaimed = true;

                uint256 toNextDay = SafeMath.sub(unclaimedAmount, teamAmount);
                currencyDividends.currentDayTokens = toNextDay;
            } else {
                 teamAmount = SafeMath.sub(prevDayTokens, userDividendsAmount);
                 currencyDividends.currentDayTokens = 0;
                 haveUnclaimed = false;
            }

            currencyDividends.claimedTodayTokens = 0;

        }
    }

    function _transferTeamHex(uint256 _amount, bool _haveUnclaimed) internal {
        (uint256 firstAmount, uint256 secondAmount) = _getTeamAmounts(_amount, _haveUnclaimed);
        IERC20(hexToken).transfer(teamAddress, firstAmount);
        IERC20(hexToken).transfer(secondTeamAddress, secondAmount);
    }

    function _transferTeamHxy(uint256 _amount, bool _haveUnclaimed) internal {
        (uint256 firstAmount, uint256 secondAmount) = _getTeamAmounts(_amount, _haveUnclaimed);
        HXY(hxyToken).transfer(teamAddress, firstAmount);
        HXY(hxyToken).transfer(secondTeamAddress, secondAmount);
    }

    function _transferTeamEth(uint256 _amount, bool _haveUnclaimed) internal {
        (uint256 firstAmount, uint256 secondAmount) = _getTeamAmounts(_amount, _haveUnclaimed);
        teamAddress.transfer(firstAmount);
        secondTeamAddress.transfer(secondAmount);
    }

    function _getTeamAmounts(uint256 fullAmount, bool haveUnclaimed) internal pure returns (uint256 firstAmount, uint256 secondAmount) {
        if (haveUnclaimed) {
            firstAmount = SafeMath.div(SafeMath.mul(fullAmount, 9), 10);
            secondAmount = SafeMath.sub(fullAmount, firstAmount);
        } else {
            firstAmount = SafeMath.div(fullAmount, 2);
            secondAmount = SafeMath.sub(fullAmount, firstAmount);
        }

    }
}