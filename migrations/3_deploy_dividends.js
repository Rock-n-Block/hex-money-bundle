require('dotenv').config({ path: '../.env' })

const HxyToken = artifacts.require('./token/HXY.sol');
const HexDividends = artifacts.require('./HexMoneyDividends.sol');


module.exports = async function (deployer, network, accounts) {

    // // STAGE 3
    return deployer.then(async () => {
        const hxyToken = await HxyToken.deployed()
        const {
            HEX_TOKEN,
            USDC_TOKEN,
            DIVIDENDS_INITIAL_RECORD_TIME,
            TEAM_10_PERCENT_ADDRESS,
            TEAM_UNCLAIMED_60_PERCENT_ADDRESS,
            TEAM_UNCLAIMED_40_PERCENT_ADDRESS
        } = process.env
        console.log('Deploying HEX Dividends');
        console.log('Deploy parameters:');
        console.log('  HEX Money (HXY) Token address: ', hxyToken.address);
        console.log('  HEX (HEX) Token address: ', HEX_TOKEN);
        console.log('  USD Coin (USDC) Token address: ', USDC_TOKEN);
        console.log('  10% dividends distribution address: ', TEAM_10_PERCENT_ADDRESS);
        console.log('  Unclaimed 60% dividends distribution address: ', TEAM_UNCLAIMED_60_PERCENT_ADDRESS);
        console.log('  Unclaimed 40% dividends distribution address: ', TEAM_UNCLAIMED_40_PERCENT_ADDRESS);
        const  hexDividends = await deployer.deploy(
            HexDividends,
            hxyToken.address,
            HEX_TOKEN,
            USDC_TOKEN,
            TEAM_10_PERCENT_ADDRESS,
            TEAM_UNCLAIMED_60_PERCENT_ADDRESS,
            TEAM_UNCLAIMED_40_PERCENT_ADDRESS,
            DIVIDENDS_INITIAL_RECORD_TIME
        );
        console.log('HEX Dividends address: ', hexDividends.address);
    })



}