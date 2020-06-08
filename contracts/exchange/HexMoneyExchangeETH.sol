pragma solidity ^0.6.2;

import "./HexMoneyExchangeBase.sol";
import "../UniswapGetters/IUniswapExchangeAmountGetters.sol";


contract HexMoneyExchangeETH is HexMoneyExchangeBase {

    address internal uniswapGetterInstance;


    constructor (HXY _hxyToken, address payable _dividendsContract)
    HexMoneyExchangeBase(_hxyToken, _dividendsContract)
    public {
        decimals = 10 ** 18;
        minAmount = 10 ** 14;
        maxAmount = SafeMath.mul(10 ** 5, decimals);
    }

    function getUniswapGetterInstance() public view returns (address) {
        return uniswapGetterInstance;
    }

    function setUniswapGetterInstance(address newUniswapGetterInstance)  public onlyAdminRole {
        uniswapGetterInstance = newUniswapGetterInstance;
    }

    function getConvertedAmount(uint256 _amount) public view returns (uint256) {
        return IUniswapExchangeAmountGetters(uniswapGetterInstance).getEthToTokenInputPrice(_amount);
    }

        // Assets Transfers
    receive() external payable {
        require(msg.value > 0, "cannot be zero payment");
        _validateAmount(msg.value);
        uint256 hexAmount = IUniswapExchangeAmountGetters(uniswapGetterInstance).getEthToTokenInputPrice(msg.value);

        HXY(hxyToken).mintFromDapp(_msgSender(), hexAmount);
        _addToDividends(msg.value);
    }

    function exchangeEth() public payable {
        require(msg.value > 0, "cannot be zero payment");
        uint256 hexAmount = IUniswapExchangeAmountGetters(uniswapGetterInstance).getEthToTokenInputPrice(msg.value);

        HXY(hxyToken).mintFromDapp(_msgSender(), hexAmount);
        _addToDividends(msg.value);
    }

    function _addToDividends(uint256 _amount) internal override {
        HexMoneyDividends(dividendsContract).recordDividendsETH{value: _amount}();
    }


}
