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


contract HexMoneyContract is AccessControl, ReentrancyGuard, HexMoneySettings {
    // bytes32 public constant MINTER_ROLE = keccak256("MANAGEMENT_ROLE");

    ERC20 internal hexToken;
    HXY internal hxyToken;
    HexWhitelist internal whitelist;

    uint256 internal hexDecimals = 10 ** 8;
    uint256 internal minHexAmount = SafeMath.mul(10 ** 3, hexDecimals);
    uint256 internal maxHexAmount = SafeMath.mul(10 ** 9, hexDecimals);

    uint256 internal hexDividendsPercentage = 20;

    struct HexDividends {
        uint256 previousDayTokens;
        uint256 currentDayTokens;
        uint256 recordTime;
    }

    HexDividends internal dividends;

    constructor (ERC20 newHexToken, HXY newHxyToken) public {
        require(address(newHexToken) != address(0x0), "hex token address should not be empty");
        require(address(newHxyToken) != address(0x0), "hxy token address should not be empty");
        hexToken = newHexToken;
        hxyToken = newHxyToken;
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

    function getWhitelistAddress() public view returns (address) {
        return address(whitelist);
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

        uint256 amount = SafeMath.div(dailyDividendsAmount,userFrozenBalance);
        require(IERC20(hexToken).transferFrom(address(this), msg.sender, amount), "fail in transfer dividends");
    }

    function setDividendsPercent(uint256 newPercentage) public returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        require(newPercentage < 100, "invalid hex percentage");
        hexDividendsPercentage = newPercentage;
        return true;
    }

    function setMinHexAmount(uint256 newAmount) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        minHexAmount = SafeMath.mul(newAmount, hexDecimals);
    }

    function setMaxHexAmount(uint256 newAmount) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        maxHexAmount = SafeMath.mul(newAmount, hexDecimals);
    }

    function setWhitelist(address newWhitelistAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        require(newWhitelistAddress != address(0x0), "Invalid whitelist address");
        whitelist = HexWhitelist(newWhitelistAddress);
    }

    function setHexToken(address newHexToken) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        require(newHexToken != address(0x0), "Invalid HEX token address");
        hexToken = ERC20(newHexToken);
    }

    function setHxyToken(address newHxyToken) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        require(newHxyToken != address(0x0), "Invalid HXY token address");
        hxyToken = HXY(newHxyToken);
    }

    function _recordDividends(uint256 amount) internal {
        if (block.timestamp > dividends.recordTime) {
            dividends.recordTime = SafeMath.add(dividends.recordTime, secondsInDay);
            dividends.previousDayTokens = dividends.currentDayTokens;
            dividends.currentDayTokens = 0;
        }

        dividends.currentDayTokens = SafeMath.add(dividends.currentDayTokens, amount);
    }
}