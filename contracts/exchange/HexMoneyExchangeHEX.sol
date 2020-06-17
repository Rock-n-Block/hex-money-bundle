pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HexMoneyExchangeBase.sol";

contract HexMoneyExchangeHEX is HexMoneyExchangeBase {
    IERC20 internal hexToken;

    constructor (HXY _hxyToken, IERC20 _hexToken,  address payable _dividendsContract, address _adminAddress)
    public
    HexMoneyExchangeBase(_hxyToken, _dividendsContract, _adminAddress)
    {
        require(address(_hexToken) != address(0x0), "hex token address should not be empty");
        hexToken = _hexToken;

        decimals = 10 ** 8;
        minAmount = SafeMath.mul(10 ** 3, decimals);
        maxAmount = SafeMath.mul(10 ** 9, decimals);
    }

    function getHexTokenAddress() public view returns (address) {
        return address(hexToken);
    }

    function exchangeHex(uint256 amount) public {
        require(IERC20(hexToken).transferFrom(_msgSender(), address(this), amount), "exchange amount greater than approved");
        _validateAmount(amount);

        HXY(hxyToken).mintFromExchange(_msgSender(), amount);
        _addToDividends(amount);
    }


    function _addToDividends(uint256 _amount) internal override {
        IERC20(hexToken).approve(address(dividendsContract), _amount);
        HexMoneyDividends(dividendsContract).recordDividendsHEX(_amount);
    }
}