pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HexMoneyExchangeBase.sol";
import "../UniswapGetters/IUniswapExchangeAmountGetters.sol";

contract HexMoneyExchangeUSDC is HexMoneyExchangeBase {
    IERC20 internal usdcToken;

    address internal uniswapGetterInstanceEth;
    address internal uniswapGetterInstanceUsdc;

    constructor (
        HXY _hxyToken,
        IERC20 _usdcToken,
        address payable _dividendsContract,
        address _uniswapEth,
        address _uniswapUsdc,
        address _adminAddress
    )
    public
    HexMoneyExchangeBase(_hxyToken, _dividendsContract, _adminAddress)
    {
        require(address(_usdcToken) != address(0x0), "erc20 token address should not be empty");
        require(address(_uniswapEth) != address(0x0), "hex token address should not be empty");
        require(address(_uniswapUsdc) != address(0x0), "hex token address should not be empty");
        usdcToken = _usdcToken;

        uniswapGetterInstanceEth = _uniswapEth;
        uniswapGetterInstanceUsdc = _uniswapUsdc;
        decimals = 10 ** 8;
        minAmount = 10 ** 5;
        maxAmount = SafeMath.mul(10 ** 6, decimals);
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

        HXY(hxyToken).mintFromExchange(_msgSender(), hexAmount);
        _addToDividends(amount);
    }

    function setUniswapGetterInstanceEth(address _uniswapGetterInstanceEth)  public onlyAdminOrDeployerRole {
        uniswapGetterInstanceEth = _uniswapGetterInstanceEth;
    }

    function setUniswapGetterInstanceUsdc(address _uniswapGetterInstanceUsdc)  public onlyAdminOrDeployerRole {
        uniswapGetterInstanceUsdc = _uniswapGetterInstanceUsdc;
    }

    function _addToDividends(uint256 _amount) internal override {
        IERC20(usdcToken).approve(address(dividendsContract), _amount);
        HexMoneyDividends(dividendsContract).recordDividendsUSDC(_amount);
    }
}