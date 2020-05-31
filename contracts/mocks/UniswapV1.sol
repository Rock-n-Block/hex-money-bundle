pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../UniswapGetters/IUniswapExchangeAmountGetters.sol";


/**
 * @dev Implementation of the Uniswap Exchange Getterts V1.
 */
contract UniswapV1 is IUniswapExchangeAmountGetters {
    using SafeMath for uint256;

    uint256 private _rate;

    constructor(uint256 rate) public {
        _rate = rate;
    }

    function rate() public view returns (uint256) {
        return _rate;
    }

    function getEthToTokenInputPrice(uint256 ethSold)
        external
        override
        view
        returns (uint256)
    {
        return ethSold.div(_rate);
    }

    function getEthToTokenOutputPrice(uint256 tokensBought)
        external
        override
        view
        returns (uint256)
    {
        return tokensBought.mul(_rate);
    }

    function getTokenToEthInputPrice(uint256 tokensSold)
        external
        override
        view
        returns (uint256)
    {
        return tokensSold.mul(_rate);
    }

    function getTokenToEthOutputPrice(uint256 ethBought)
        external
        override
        view
        returns (uint256)
    {
        return ethBought.div(_rate);
    }
}
