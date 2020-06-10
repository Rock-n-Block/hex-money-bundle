pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HexMoneyExchangeBase.sol";

contract HexMoneyExchangeUSDC is HexMoneyExchangeBase {
    IERC20 internal usdcToken;

    constructor (IERC20 _usdcToken, HXY _hxyToken, address payable _dividendsContract)
    HexMoneyExchangeBase(_hxyToken, _dividendsContract)
    public {
        require(address(_usdcToken) != address(0x0), "erc20 token address should not be empty");
        usdcToken = _usdcToken;

        decimals = 10 ** 18;
        minAmount = SafeMath.mul(10 ** 3, decimals);
        maxAmount = SafeMath.mul(10 ** 9, decimals);
    }

    function getUsdcTokenAddress() public view returns (address) {
        return address(usdcToken);
    }

    function exchangeUsdc(uint256 amount) public {
        require(IERC20(usdcToken).transferFrom(_msgSender(), address(this), amount), "exchange amount greater than approved");
        _validateAmount(amount);

        HXY(hxyToken).mintFromDapp(_msgSender(), amount);
        _addToDividends(amount);
    }

    function setUsdcToken(address newUsdcToken) public onlyAdminRole {
        require(newUsdcToken != address(0x0), "Invalid USDC token address");
        usdcToken = IERC20(newUsdcToken);
    }

    function _addToDividends(uint256 _amount) internal override {
        IERC20(usdcToken).approve(address(dividendsContract), _amount);
        //HexMoneyDividends(dividendsContract).recordDividendsUSDC(_amount);
    }
}