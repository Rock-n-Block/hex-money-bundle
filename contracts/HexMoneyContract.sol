pragma solidity ^0.6.2;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
//import "./token/ERC20/ERC20.sol";
import "./token/ERC20.sol";
import "./token/HXY.sol";
import "./HexWhitelist.sol";
import "./HexMoneySettings.sol";


contract HexMoneyContract is ReentrancyGuard, HexMoneySettings {
    ERC20 internal hexToken;
    HXY internal hxyToken;

    uint256 internal hexDecimals = 10 ** 8;
    uint256 internal minHexAmount = SafeMath.mul(10 ** 3, hexDecimals);
    uint256 internal maxHexAmount = SafeMath.mul(10 ** 9, hexDecimals);

    uint256 internal hexDividendsPercentage = 90;

    struct HexDividends {
        uint256 teamTokens;
        uint256 previousDayTokens;
        uint256 currentDayTokens;
        uint256 recordTime;
    }

    HexDividends internal dividends;

    constructor (ERC20 newHexToken, HXY newHxyToken, address _teamAddress) public {
        require(address(newHexToken) != address(0x0), "hex token address should not be empty");
        require(address(newHxyToken) != address(0x0), "hxy token address should not be empty");
        hexToken = newHexToken;
        hxyToken = newHxyToken;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(TEAM_ROLE, _teamAddress);
        teamAddress = _teamAddress;
    }

    function getMinHexAmount() public view returns (uint256) {
        return minHexAmount;
    }

    function getMaxHexAmount() public view returns (uint256) {
        return maxHexAmount;
    }

    function getHexDividendsPercentage() public view returns (uint256) {
        return hexDividendsPercentage;
    }

    function getHexTokenAddress() public view returns (address) {
        return address(hexToken);
    }

    function getHxyTokenAddress() public view returns (address) {
        return address(hxyToken);
    }

    function exchangeHex(uint256 amount) public {
        require(IERC20(hexToken).transferFrom(msg.sender, address(this), amount), "exchange amount greater than approved");

        HXY(hxyToken).mintFromExchange(msg.sender, amount);
        _recordDividends(amount);
    }

    function claimDividends() public {
        uint256 dailyDividendsAmount = SafeMath.div(dividends.previousDayTokens, hexDividendsPercentage);
        uint256 userFrozenBalance = HXY(hxyToken).freezingBalanceOf(msg.sender);
        require(userFrozenBalance != 0, "must be freezed amount of HXY to claim dividends");

        uint256 totalFrozen = HXY(hxyToken).getTotalFrozen();
        uint256 userFrozenPercentage = SafeMath.div(userFrozenBalance, totalFrozen);
        uint256 amount = SafeMath.mul(dailyDividendsAmount,userFrozenPercentage);
        require(IERC20(hexToken).transferFrom(address(this), msg.sender, amount), "fail in transfer dividends");
    }

    function claimPastDividendsTeam() public onlyTeamRole {
        uint256 amount = dividends.teamTokens;
        require(IERC20(hexToken).transferFrom(address(this), teamAddress, amount), "fail in transfer past dividends");
        dividends.teamTokens = 0;
    }

    function setDividendsPercent(uint256 newPercentage) public onlyAdminRole {
        require(newPercentage < 100, "invalid hex percentage");
        hexDividendsPercentage = newPercentage;
    }

    function setMinHexAmount(uint256 newAmount) public onlyAdminRole {
        minHexAmount = SafeMath.mul(newAmount, hexDecimals);
    }

    function setMaxHexAmount(uint256 newAmount) public onlyAdminRole {
        maxHexAmount = SafeMath.mul(newAmount, hexDecimals);
    }

    function setHexToken(address newHexToken) public onlyAdminRole {
        require(newHexToken != address(0x0), "Invalid HEX token address");
        hexToken = ERC20(newHexToken);
    }

    function setHxyToken(address newHxyToken) public onlyAdminRole {
        require(newHxyToken != address(0x0), "Invalid HXY token address");
        hxyToken = HXY(newHxyToken);
    }

    function _recordDividends(uint256 amount) internal {
        if (block.timestamp > dividends.recordTime) {
            dividends.recordTime = SafeMath.add(dividends.recordTime, secondsInDay);
            dividends.teamTokens = SafeMath.add(dividends.teamTokens, dividends.previousDayTokens);
            dividends.previousDayTokens = dividends.currentDayTokens;
            dividends.currentDayTokens = 0;
        }

        dividends.currentDayTokens = SafeMath.add(dividends.currentDayTokens, amount);
    }
}