pragma solidity ^0.6.0;

import "./IUniswapExchangeAmountGetters.sol";


/**
 * @dev Implementation of the Uniswap Exchange Amount Getterts.
 */
contract UniswapExchangeAmountGettersV1 is IUniswapExchangeAmountGetters {
    address private _exchange;

    /**
     * @dev Sets the value for `exchange`.
     * @param exchangeAddress The address of uniswap exchange instance.
     * @notice `exchangeAddress` value is immutable: it can only be
     * set once during construction
     */
    constructor(address exchangeAddress) public {
        _exchange = exchangeAddress;
    }

    /**
     * @dev Returns the address of uniswap exchange instance.
     */
    function exchange() public view returns (address) {
        return _exchange;
    }

    /**
     * @dev See {IUniswapExchangeAmountGetters-getEthToTokenInputPrice}.
     */
    function getEthToTokenInputPrice(uint256 ethSold)
        public
        override
        view
        returns (uint256)
    {
        return
            IUniswapExchangeAmountGetters(_exchange).getEthToTokenInputPrice(
                ethSold
            );
    }

    /**
     * @dev See {IUniswapExchangeAmountGetters-getEthToTokenOutputPrice}.
     */
    function getEthToTokenOutputPrice(uint256 tokensBought)
        public
        override
        view
        returns (uint256)
    {
        return
            IUniswapExchangeAmountGetters(_exchange).getEthToTokenOutputPrice(
                tokensBought
            );
    }

    /**
     * @dev See {IUniswapExchangeAmountGetters-getTokenToEthInputPrice}.
     */
    function getTokenToEthInputPrice(uint256 tokensSold)
        public
        override
        view
        returns (uint256)
    {
        return
            IUniswapExchangeAmountGetters(_exchange).getTokenToEthInputPrice(
                tokensSold
            );
    }

    /**
     * @dev See {IUniswapExchangeAmountGetters-getTokenToEthOutputPrice}.
     */
    function getTokenToEthOutputPrice(uint256 ethBought)
        public
        override
        view
        returns (uint256)
    {
        return
            IUniswapExchangeAmountGetters(_exchange).getTokenToEthOutputPrice(
                ethBought
            );
    }
}
