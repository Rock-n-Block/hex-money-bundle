pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../token/HXY.sol";
import "../HexWhitelist.sol";
import "../HexMoneySettings.sol";
import "../interfaces/IUniswapExchangeAmountGettersV1.sol";


contract HexMoneyETH is ReentrancyGuard, HexMoneySettings {
    struct HexDividends {
        uint256 teamTokens;
        uint256 previousDayTokens;
        uint256 currentDayTokens;
        uint256 recordTime;
    }

    IERC20 internal hexToken;
    HXY internal hxyToken;
    HexDividends internal dividends;

    mapping(address => uint256) internal userClaimedHexDividends;
    mapping(address => uint256) internal lastHexClaim;

    uint256 internal hexDecimals = 10**8;
    uint256 internal minHexAmount = SafeMath.mul(10**3, hexDecimals);
    uint256 internal maxHexAmount = SafeMath.mul(10**9, hexDecimals);
    uint256 internal hexDividendsPercentage = 90;
    uint256 internal claimedHexDividends;

    address internal exchange;

    constructor(
        IERC20 newHexToken,
        HXY newHxyToken,
        address _teamAddress,
        address _exchange
    ) public {
        require(
            address(newHexToken) != address(0x0),
            "hex token address should not be empty"
        );
        require(
            address(newHxyToken) != address(0x0),
            "hxy token address should not be empty"
        );
        hexToken = newHexToken;
        hxyToken = newHxyToken;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(TEAM_ROLE, _teamAddress);
        teamAddress = _teamAddress;
        exchange = _exchange;
    }

    // Getters
    function getExchangeAddress() public view returns (address) {
        return exchange;
    }

    function getClaimedHexDividends() public view returns (uint256) {
        return userClaimedHexDividends[_msgSender()];
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

    // Setters
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

    // Internal
    function _setInitialRecordTime(uint256 _recordTime) internal {
        dividends.recordTime = _recordTime;
    }

    function _recordDividends(uint256 amount) internal {
        _checkUpdateDividends();
        dividends.currentDayTokens = SafeMath.add(
            dividends.currentDayTokens,
            amount
        );
    }

    function _checkUpdateDividends() internal {
        if (block.timestamp > dividends.recordTime) {
            uint256 daysPassed = SafeMath.div(
                SafeMath.sub(block.timestamp, dividends.recordTime),
                SECONDS_IN_DAY
            );
            dividends.recordTime = SafeMath.add(
                dividends.recordTime,
                SafeMath.mul(daysPassed, SECONDS_IN_DAY)
            );
            if (daysPassed <= 1) {
                dividends.teamTokens = SafeMath.add(
                    dividends.teamTokens,
                    dividends.previousDayTokens
                );
                dividends.previousDayTokens = dividends.currentDayTokens;
            } else {
                uint256 prevAndCurrentTokens = SafeMath.add(
                    dividends.previousDayTokens,
                    dividends.currentDayTokens
                );
                dividends.teamTokens = SafeMath.add(
                    dividends.teamTokens,
                    prevAndCurrentTokens
                );
                dividends.previousDayTokens = 0;
            }
            dividends.currentDayTokens = 0;
        }
    }

    // Assets Transfers
    receive() external payable {
        IUniswapExchangeAmountGettersV1(exchange).getEthToTokenInputPrice(
            msg.value
        );

        HXY(hxyToken).mintFromExchange(_msgSender(), msg.value);
        _recordDividends(msg.value);
    }

    function exchangeHex() public payable {
        IUniswapExchangeAmountGettersV1(exchange).getEthToTokenInputPrice(
            msg.value
        );

        HXY(hxyToken).mintFromExchange(_msgSender(), msg.value);
        _recordDividends(msg.value);
    }

    function claimDividends() public {
        require(
            lastHexClaim[_msgSender()] <= dividends.recordTime,
            "tokens already claimed today"
        );
        _checkUpdateDividends();
        uint256 dailyDividendsAmount = SafeMath.div(
            SafeMath.mul(dividends.previousDayTokens, hexDividendsPercentage),
            100
        );
        uint256 userFrozenBalance = HXY(hxyToken).freezingBalanceOf(
            _msgSender()
        );
        require(
            userFrozenBalance != 0,
            "must be freezed amount of HXY to claim dividends"
        );

        uint256 totalFrozen = HXY(hxyToken).getTotalFrozen();
        uint256 userFrozenPercentage = SafeMath.div(
            userFrozenBalance,
            totalFrozen
        );
        uint256 amount = SafeMath.mul(
            dailyDividendsAmount,
            userFrozenPercentage
        );
        require(
            IERC20(hexToken).transfer(_msgSender(), amount),
            "fail in transfer dividends"
        );

        userClaimedHexDividends[_msgSender()] = SafeMath.add(
            userClaimedHexDividends[_msgSender()],
            amount
        );
        claimedHexDividends = SafeMath.add(claimedHexDividends, amount);
        lastHexClaim[_msgSender()] = block.timestamp;
    }

    function claimPastDividendsTeam() public onlyTeamRole {
        uint256 amount = dividends.teamTokens;
        require(
            IERC20(hexToken).transferFrom(address(this), teamAddress, amount),
            "fail in transfer past dividends"
        );
        dividends.teamTokens = 0;
    }
}
