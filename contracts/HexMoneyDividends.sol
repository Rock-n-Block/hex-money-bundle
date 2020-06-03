pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./base/HexMoneyTeam.sol";
import "./base/HexMoneyInternal.sol";

import "./token/HXY.sol";

contract HexMoneyDividends is HexMoneyTeam, HexMoneyInternal {
    IERC20 internal hexToken;
    HXY internal hxyToken;

    bool internal _initialRecordTimeSet;

    mapping (address => uint256) internal userClaimedHexDividends;
    mapping (address => uint256) internal lastHexClaim;

    uint256 internal hexDecimals = 10 ** 8;
    uint256 internal dividendsPercentage = 90;

    struct DividendsCurrency {
        uint256 teamTokens;
        uint256 previousDayTokens;
        uint256 currentDayTokens;
    }

    struct Dividends {
        DividendsCurrency hexDividends;
        DividendsCurrency hxyDividends;
        DividendsCurrency ethDividends;
        uint256 recordTime;
    }

    struct DividendsTotalClaimed {
        uint256 hexAmount;
        uint256 hxyAmount;
        uint256 ethAmount;
    }

//    struct DividendsUserClaimedCurrency {
//        uint256 amount;
//        uint256 lastClaim;
//    }

    struct DividendsUserClaimed {
        uint256 hexAmount;
        uint256 hxyAmount;
        uint256 ethAmount;
        uint256 lastClaim;
//        DividendsUserClaimedCurrency storage hex;
//        DividendsUserClaimedCurrency storage hxy;
//        DividendsUserClaimedCurrency storage eth;
    }

    Dividends internal dividends;
    DividendsTotalClaimed internal totalClaimedDividends;

    mapping(address => DividendsUserClaimed) internal userClaimedDividends;

    constructor (IERC20 newHexToken, HXY newHxyToken, address _teamAddress) public {
        require(address(newHexToken) != address(0x0), "hex token address should not be empty");
        require(address(newHxyToken) != address(0x0), "hxy token address should not be empty");
        hexToken = newHexToken;
        hxyToken = newHxyToken;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(TEAM_ROLE, _teamAddress);
        teamAddress = _teamAddress;

        //_setInitialRecordTime(_recordTime);
    }

    function getClaimedDividends(address _addr) public view returns (uint256[4] memory) {
        DividendsUserClaimed memory divs = userClaimedDividends[_addr];
        return [divs.hexAmount, divs.hxyAmount, divs.ethAmount, divs.lastClaim];
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
        }
    }

    function _processClaimHxy(uint256 _userFrozenPercentage) internal {
        uint256 amount = _getClaimAmount(dividends.hxyDividends.previousDayTokens, _userFrozenPercentage);

        if (amount != 0) {
            require(IERC20(hxyToken).transfer(_msgSender(), amount), "fail in transfer HXY dividends");

            userClaimedDividends[_msgSender()].hxyAmount = SafeMath.add(userClaimedDividends[_msgSender()].hxyAmount, amount);
            totalClaimedDividends.hxyAmount = SafeMath.add(totalClaimedDividends.hxyAmount, amount);
        }
    }

    function _processClaimEth(uint256 _userFrozenPercentage) internal {
        uint256 amount = _getClaimAmount(dividends.ethDividends.previousDayTokens, _userFrozenPercentage);

        if (amount != 0) {
            _msgSender().transfer(amount);

            userClaimedDividends[_msgSender()].ethAmount = SafeMath.add(userClaimedDividends[_msgSender()].ethAmount, amount);
            totalClaimedDividends.ethAmount = SafeMath.add(totalClaimedDividends.ethAmount, amount);
        }
    }

    function _getClaimAmount(uint256 currencyPrevDayAmount, uint256 userFrozenPercentage) internal view returns (uint256) {
        uint256 dailyDividendsAmount = SafeMath.div(SafeMath.mul(currencyPrevDayAmount, dividendsPercentage), 100);
        return SafeMath.mul(dailyDividendsAmount,userFrozenPercentage);
    }

    function claimPastDividendsTeam() public onlyTeamRole {
        uint256 amount = dividends.hexDividends.teamTokens;
        require(IERC20(hexToken).transferFrom(address(this), teamAddress, amount), "fail in transfer past dividends");
        dividends.hexDividends.teamTokens = 0;
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

    function _setInitialRecordTime(uint256 _recordTime) internal {
        dividends.recordTime = _recordTime;
    }

    function _postprocessDividends(DividendsCurrency storage currencyDividends, uint256 _amount) internal {
        _checkUpdateDividendsAll();
        currencyDividends.currentDayTokens = SafeMath.add(currencyDividends.currentDayTokens, _amount);
    }

    function _checkUpdateDividendsAll() internal {
        _checkUpdateDividends(dividends.hexDividends);
        _checkUpdateDividends(dividends.hxyDividends);
        _checkUpdateDividends(dividends.ethDividends);
    }

    function _checkUpdateDividends(DividendsCurrency storage currencyDividends) internal {
        if (block.timestamp > dividends.recordTime) {
            uint256 daysPassed = SafeMath.div(SafeMath.sub(block.timestamp, dividends.recordTime), SECONDS_IN_DAY);
            dividends.recordTime = SafeMath.add(dividends.recordTime, SafeMath.mul(daysPassed, SECONDS_IN_DAY));
            if (daysPassed <= 1) {
                currencyDividends.teamTokens = SafeMath.add(currencyDividends.teamTokens, currencyDividends.previousDayTokens);
                currencyDividends.previousDayTokens = currencyDividends.currentDayTokens;
            } else {
                uint256 prevAndCurrentTokens = SafeMath.add(currencyDividends.previousDayTokens, currencyDividends.currentDayTokens);
                currencyDividends.teamTokens = SafeMath.add(currencyDividends.teamTokens, prevAndCurrentTokens);
                currencyDividends.previousDayTokens = 0;
            }
            currencyDividends.currentDayTokens = 0;

        }
    }
}