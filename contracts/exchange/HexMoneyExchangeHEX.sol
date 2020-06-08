pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HexMoneyExchangeBase.sol";

contract HexMoneyExchangeHEX is HexMoneyExchangeBase {
    IERC20 internal hexToken;

    constructor (IERC20 _hexToken, HXY _hxyToken, address payable _dividendsContract)
    HexMoneyExchangeBase(_hxyToken, _dividendsContract)
    public {
        require(address(_hexToken) != address(0x0), "erc20 token address should not be empty");
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

        HXY(hxyToken).mintFromDapp(_msgSender(), amount);
        _addToDividends(amount);
    }

    function setHexToken(address newHexToken) public onlyAdminRole {
        require(newHexToken != address(0x0), "Invalid HEX token address");
        hexToken = IERC20(newHexToken);
    }

    function _addToDividends(uint256 _amount) internal override {
        IERC20(hexToken).approve(address(dividendsContract), _amount);
        HexMoneyDividends(dividendsContract).recordDividendsHEX(_amount);
    }
}