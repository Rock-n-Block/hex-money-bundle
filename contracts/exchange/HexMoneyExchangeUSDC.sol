pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HexMoneyExchangeBase.sol";
import "../UniswapGetters/IUniswapExchangeAmountGetters.sol";

contract HexMoneyExchangeUSDC is HexMoneyExchangeBase {
    IERC20 internal usdcToken;

    address internal uniswapGetterInstanceEth;
    address internal uniswapGetterInstanceUsdc;

    constructor (IERC20 _usdcToken, HXY _hxyToken, address payable _dividendsContract)
    HexMoneyExchangeBase(_hxyToken, _dividendsContract)
    public {
        require(address(_usdcToken) != address(0x0), "erc20 token address should not be empty");
        usdcToken = _usdcToken;

        decimals = 10 ** 18;
        minAmount = SafeMath.mul(10 ** 3, decimals);
        maxAmount = SafeMath.mul(10 ** 9, decimals);
    }

    function getUniswapGetterInstanceEth() public view returns (address) {
        return uniswapGetterInstanceEth;
    }

    function getUniswapGetterInstanceUsdc() public view returns (address) {
        return uniswapGetterInstanceUsdc;
    }

    function getConvertedAmount(uint256 _amount) public view returns (uint256) {
        uint256 ethAmount = IUniswapExchangeAmountGetters(uniswapGetterInstanceUsdc).getTokenToEthInputPrice(_amount);
        uint256 hexAmount = IUniswapExchangeAmountGetters(uniswapGetterInstanceEth).getEthToTokenInputPrice(ethAmount);
        return hexAmount;
    }


    function getUsdcTokenAddress() public view returns (address) {
        return address(usdcToken);
    }

    function exchangeUsdc(uint256 amount) public {
        require(IERC20(usdcToken).transferFrom(_msgSender(), address(this), amount), "exchange amount greater than approved");
        uint256 ethAmount = IUniswapExchangeAmountGetters(uniswapGetterInstanceUsdc).getTokenToEthInputPrice(amount);
        uint256 hexAmount = IUniswapExchangeAmountGetters(uniswapGetterInstanceEth).getEthToTokenInputPrice(ethAmount);
        _validateAmount(amount);

        HXY(hxyToken).mintFromDapp(_msgSender(), hexAmount);
        _addToDividends(amount);
    }

    function setUniswapGetterInstanceEth(address _uniswapGetterInstanceEth)  public onlyAdminRole {
        uniswapGetterInstanceEth = _uniswapGetterInstanceEth;
    }

    function setUniswapGetterInstanceUsdc(address _uniswapGetterInstanceUsdc)  public onlyAdminRole {
        uniswapGetterInstanceUsdc = _uniswapGetterInstanceUsdc;
    }

    function setUsdcToken(address newUsdcToken) public onlyAdminRole {
        require(newUsdcToken != address(0x0), "Invalid USDC token address");
        usdcToken = IERC20(newUsdcToken);
    }

    function _addToDividends(uint256 _amount) internal override {
        IERC20(usdcToken).approve(address(dividendsContract), _amount);
        HexMoneyDividends(dividendsContract).recordDividendsUSDC(_amount);
    }
}