require('dotenv').config({ path: '../.env' })

const HxyToken = artifacts.require('./token/HXY.sol');

const HexWhitelist = artifacts.require('./whitelist/HexWhitelist.sol');

const HexDividends = artifacts.require('./HexMoneyDividends.sol');
const HexExchangeHEX = artifacts.require('./exchange/HexMoneyExchangeHEX.sol');
const HexExchangeETH = artifacts.require('./exchange/HexMoneyExchangeETH.sol');
const HexExchangeUSDC = artifacts.require('./exchange/HexMoneyExchangeUSDC.sol');
const HexExchangeReferral = artifacts.require('./exchange/HexMoneyReferralSender.sol');

const UniswapExchangeAmountGettersV1 = artifacts.require('./UniswapGetters/UniswapExchangeAmountGettersV1');

module.exports = async function (deployer, network, accounts) {

    // // STAGE 4
    return deployer.then(async () => {
        const hxyToken = await HxyToken.deployed();
        const dividendsContract = await HexDividends.deployed();
        const hexWhitelist = await HexWhitelist.deployed();
        const {
            HEX_TOKEN,
            USDC_TOKEN,
            UNISWAP_HEX_ETH_ADDRESS,
            UNISWAP_USDC_ETH_ADDRESS,
            EXCHANGE_DEFAULT_LIMIT,
            ADMIN_ROLE_ADDRESS
        } = process.env
        console.log('Deploying Uniswap Proxy contracts');
        console.log('Deploy parameters:');
        console.log('  HEX/ETH Uniswap address: ', UNISWAP_HEX_ETH_ADDRESS);
        console.log('  USDC/ETH Uniswap address: ', UNISWAP_USDC_ETH_ADDRESS);
        const uniswapProxyHexEth = await deployer.deploy(
            UniswapExchangeAmountGettersV1,
            UNISWAP_HEX_ETH_ADDRESS
        );
        console.log('Uniswap Proxy HEX/ETH address: ', uniswapProxyHexEth.address);
        const uniswapProxyUsdcEth = await deployer.deploy(
            UniswapExchangeAmountGettersV1,
            UNISWAP_USDC_ETH_ADDRESS
        );
        console.log('Uniswap Proxy USDC/ETH address: ', uniswapProxyUsdcEth.address);

        console.log('===========');
        console.log('Deploying HEX Referral Sender contract');
        console.log('Deploy parameters:');
        console.log('  HEX Money (HXY) Token address: ', hxyToken.address);
        console.log('  HEX Whitelist contract address: ', hexWhitelist.address);
        console.log('  Admin address: ', ADMIN_ROLE_ADDRESS);
        const hexExchangeReferralSender = await deployer.deploy(
            HexExchangeReferral,
            hxyToken.address,
            hexWhitelist.address,
            ADMIN_ROLE_ADDRESS
        );
        console.log('HEX HEX Referral Sender address: ', hexExchangeReferralSender.address);


        console.log('===========');
        console.log('Deploying HEX Exchange contract');
        console.log('Deploy parameters:');
        console.log('  HEX Money (HXY) Token address: ', hxyToken.address);
        console.log('  HEX (HEX) Token address: ', HEX_TOKEN);
        console.log('  HEX Dividends contract address: ', dividendsContract.address);
        console.log('  HEX Referral Sender contract address: ', hexExchangeReferralSender.address);
        console.log('  Admin address: ', ADMIN_ROLE_ADDRESS);
        const hexExchangeHex = await deployer.deploy(
            HexExchangeHEX,
            hxyToken.address,
            HEX_TOKEN,
            dividendsContract.address,
            hexExchangeReferralSender.address,
            ADMIN_ROLE_ADDRESS
        );
        console.log('HEX Exchange address: ', hexExchangeHex.address);

        console.log('===========');
        console.log('Deploying ETH Exchange contract');
        console.log('Deploy parameters:');
        console.log('  HEX Money (HXY) Token address: ', hxyToken.address);
        console.log('  HEX Dividends contract address: ', dividendsContract.address);
        console.log('  HEX Referral Sender contract address: ', hexExchangeReferralSender.address);
        console.log('  Uniswap Proxy HEX/ETH contract address: ', uniswapProxyHexEth.address);
        console.log('  Admin address: ', ADMIN_ROLE_ADDRESS);
        const hexExchangeEth = await deployer.deploy(
            HexExchangeETH,
            hxyToken.address,
            dividendsContract.address,
            hexExchangeReferralSender.address,
            uniswapProxyHexEth.address,
            ADMIN_ROLE_ADDRESS
        );
        console.log('ETH Exchange address: ', hexExchangeEth.address);

        console.log('===========');
        console.log('Deploying USDC Exchange contract');
        console.log('Deploy parameters:');
        console.log('  HEX Money (HXY) Token address: ', hxyToken.address);
        console.log('  USD Coin (USDC) Token address: ', USDC_TOKEN);
        console.log('  HEX Dividends contract address: ', dividendsContract.address);
        console.log('  HEX Referral Sender contract address: ', hexExchangeReferralSender.address);
        console.log('  Uniswap Proxy HEX/ETH contract address: ', uniswapProxyHexEth.address);
        console.log('  Uniswap Proxy USDC/ETH address: ', uniswapProxyUsdcEth.address);
        console.log('  Admin address: ', ADMIN_ROLE_ADDRESS);
        const hexExchangeUsdc = await deployer.deploy(
            HexExchangeUSDC,
            hxyToken.address,
            USDC_TOKEN,
            dividendsContract.address,
            hexExchangeReferralSender.address,
            uniswapProxyHexEth.address,
            uniswapProxyUsdcEth.address,
            ADMIN_ROLE_ADDRESS
        );

        console.log('USDC Exchange address: ', hexExchangeUsdc.address)

        console.log('===========');
        console.log('Registering exchanges in whitelist');
        const exchangeHexTx = await hexWhitelist.registerExchangeTradeable(hexExchangeHex.address, EXCHANGE_DEFAULT_LIMIT);
        console.log('HEX Exchange registration TXID: ', exchangeHexTx.tx);
        const exchangeEthTx = await hexWhitelist.registerExchangeTradeable(hexExchangeEth.address, EXCHANGE_DEFAULT_LIMIT)
        console.log('HEX Exchange registration TXID: ', exchangeEthTx.tx);
        const exchangeUsdcTx = await hexWhitelist.registerExchangeTradeable(hexExchangeUsdc.address, EXCHANGE_DEFAULT_LIMIT)
        console.log('HEX Exchange registration TXID: ', exchangeUsdcTx.tx);
        const refSenderTx = await hexWhitelist.registerDappNonTradeable(hexExchangeReferralSender.address, EXCHANGE_DEFAULT_LIMIT, 30)
        console.log('HEX Referral Sender registration TXID: ', refSenderTx.tx);

        console.log('Deployment completed')
    })

}