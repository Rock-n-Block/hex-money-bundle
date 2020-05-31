pragma solidity ^0.6.0;


/**
 * @dev Interface of the Uniswap Exchange Amount Getterts V1.
 */
interface IUniswapExchangeAmountGetters {
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
