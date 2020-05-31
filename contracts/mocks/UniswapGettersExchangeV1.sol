pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IUniswapGettersExchangeV1.sol";


/**
 * @dev Implementation of the Uniswap Exchange Getterts V1.
 */
contract UniswapGettersExchangeV1 is IUniswapGettersExchangeV1 {
    using SafeMath for uint256;

    uint256 constant RATE = 202881;

    function getInputPrice(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) external override view returns (uint256) { return RATE }

    function getOutputPrice(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) external override view returns (uint256) { return RATE }

    function getEthToTokenInputPrice(uint256 ethSold)
        external
        override
        view
        returns (uint256)
    {
        return ethSold.div(RATE);
    }

    function getEthToTokenOutputPrice(uint256 tokensBought)
        external
        override
        view
        returns (uint256)
    {
        return tokensBought.mul(RATE);
    }

    function getTokenToEthInputPrice(uint256 tokensSold)
        external
        override
        view
        returns (uint256)
    {
        return tokensSold.mul(RATE);
    }

    function getTokenToEthOutputPrice(uint256 ethBought)
        external
        override
        view
        returns (uint256)
    {
        return ethBought.div(RATE);
    }
}
