pragma solidity ^0.6.2;

import "./HexMoneyExchangeBase.sol";
import "../UniswapGetters/IUniswapExchangeAmountGetters.sol";


contract HexMoneyExchangeETH is HexMoneyExchangeBase {

    address internal uniswapGetterInstance;


    constructor (HXY _hxyToken, address payable _dividendsContract, address _referralSender, address _uniswapEth, address _adminAddress)
    public
    HexMoneyExchangeBase(_hxyToken, _dividendsContract, _referralSender, _adminAddress)
    {
        require(address(_uniswapEth) != address(0x0), "hex token address should not be empty");
        uniswapGetterInstance = _uniswapEth;
        decimals = 10 ** 18;
        minAmount = 10 ** 14;
        maxAmount = SafeMath.mul(10 ** 4, decimals);
    }

    function getUniswapGetterInstance() public view returns (address) {
        return uniswapGetterInstance;
    }

    function setUniswapGetterInstance(address newUniswapGetterInstance)  public onlyAdminOrDeployerRole {
        uniswapGetterInstance = newUniswapGetterInstance;
    }

    function getConvertedAmount(uint256 _amount) public view returns (uint256) {
        return IUniswapExchangeAmountGetters(uniswapGetterInstance).getEthToTokenInputPrice(_amount);
    }

        // Assets Transfers
    receive() external payable {
        _exchangeEth(_msgSender(), msg.value);
    }

    function exchangeEth() public payable {
        _exchangeEth(_msgSender(), msg.value);
    }

    function exchangeEthWithReferral(address referralAddress) public payable {
        _exchangeEth(_msgSender(), msg.value);

        uint256 hexAmount = getConvertedAmount(msg.value);
        _mintToReferral(referralAddress, hexAmount);
    }

    function _exchangeEth(address _to, uint256 _amount) internal {
        _validateAmount(_amount);
        uint256 hexAmount = getConvertedAmount(_amount);

        HXY(hxyToken).mintFromExchange(_to, hexAmount);
        _addToDividends(_amount);
    }

    function _addToDividends(uint256 _amount) internal override {
        HexMoneyDividends(dividendsContract).recordDividendsETH{value: _amount}();
    }


}
