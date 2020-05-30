pragma solidity ^0.6.0;


/**
 * @dev Interface of the Uniswap Exchange Getterts V1.
 */
interface IUniswapGettersExchangeV1 {
    /**
     * @dev Pricing function for converting between ETH and Tokens.
     * @param inputAmount Amount of ETH or Tokens being sold.
     * @param inputReserve Amount of ETH or Tokens (input type) in exchange reserves.
     * @param outputReserve Amount of ETH or Tokens (output type) in exchange reserves.
     * @return Amount of ETH or Tokens bought.
     */

    function getInputPrice(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) external view returns (uint256);

    /**
     * @dev Pricing function for converting between ETH and Tokens.
     * @param outputAmount Amount of ETH or Tokens being bought.
     * @param inputReserve Amount of ETH or Tokens (input type) in exchange reserves.
     * @param outputReserve Amount of ETH or Tokens (output type) in exchange reserves.
     * @return Amount of ETH or Tokens sold.
     */
    function getOutputPrice(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) external view returns (uint256);

    /**
     * @notice Public price function for ETH to Token trades with an exact input.
     * @param ethSold Amount of ETH sold.
     * @return Amount of Tokens that can be bought with input ETH.
     */
    function getEthToTokenInputPrice(uint256 ethSold)
        external
        view
        returns (uint256);

    /**
     * @notice Public price function for ETH to Token trades with an exact output.
     * @param tokensBought Amount of Tokens bought.
     * @return Amount of ETH needed to buy output Tokens.
     */
    function getEthToTokenOutputPrice(uint256 tokensBought)
        external
        view
        returns (uint256);

    /**
     * @notice Public price function for Token to ETH trades with an exact input.
     * @param tokensSold Amount of Tokens sold.
     * @return Amount of ETH that can be bought with input Tokens.
     */
    function getTokenToEthInputPrice(uint256 tokensSold)
        external
        view
        returns (uint256);

    /**
     * @notice Public price function for Token to ETH trades with an exact output.
     * @param ethBought Amount of output ETH.
     * @return Amount of Tokens needed to buy output ETH.
     */
    function getTokenToEthOutputPrice(uint256 ethBought)
        external
        view
        returns (uint256);
}
