require('dotenv').config({ path: '../.env' })

const HxyToken = artifacts.require('./token/HXY.sol');
const HexWhitelist = artifacts.require('./whitelist/HexWhitelist.sol');
const QueueLib = artifacts.require('./libs/QueueLib.sol');

module.exports = async function (deployer, network, accounts) {

    // // STAGE 2
    return deployer.then(async () => {
        const whitelist = await HexWhitelist.deployed();
        const {
            HEX_MONEY_LIQUID_SUPPLY_ADDRESS,
            HEX_MONEY_LIQUID_SUPPLY_AMOUNT,
            HEX_MONEY_LOCKED_SUPPLY_FIRST_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_SECOND_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_THIRD_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_FOURTH_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_FIFTH_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_SIXTH_ADDRESS,
            UNLOCK_FIRST_TIME,
            UNLOCK_SECOND_TIME,
            UNLOCK_THIRD_TIME,
            UNLOCK_FOURTH_TIME,
            UNLOCK_FIFTH_TIME,
            UNLOCK_SIXTH_TIME,
            UNLOCK_SEVEN_TIME,
            UNLOCK_EIGHT_TIME,
            UNLOCK_NINE_TIME,
            UNLOCK_TEN_TIME
        } = process.env

        console.log('Deploying HEX Money (HXY) Token');
        console.log('Deploy parameters:');
        console.log('  HEX Whitelist address: ', whitelist.address);
        console.log('  Liquid supply address: ', HEX_MONEY_LIQUID_SUPPLY_ADDRESS);
        console.log('  Locked supply first address: ', HEX_MONEY_LOCKED_SUPPLY_FIRST_ADDRESS);
        console.log('  Locked supply second address: ', HEX_MONEY_LOCKED_SUPPLY_SECOND_ADDRESS);
        console.log('  Locked supply third address: ', HEX_MONEY_LOCKED_SUPPLY_THIRD_ADDRESS);
        console.log('  Locked supply fourth address: ', HEX_MONEY_LOCKED_SUPPLY_FOURTH_ADDRESS);
        console.log('  Locked supply fifth address: ', HEX_MONEY_LOCKED_SUPPLY_FIFTH_ADDRESS);
        console.log('  Locked supply sixth address: ', HEX_MONEY_LOCKED_SUPPLY_SIXTH_ADDRESS);
        const hxyToken = await deployer.deploy(
            HxyToken,
            whitelist.address,
            HEX_MONEY_LIQUID_SUPPLY_ADDRESS,
            HEX_MONEY_LIQUID_SUPPLY_AMOUNT
        );
        //const hxyToken = await HxyToken.deployed()
        console.log('HEX Money (HXY) Token address: ', hxyToken.address);
        const myTx = await hxyToken.premintLocked(
            [
                HEX_MONEY_LOCKED_SUPPLY_FIRST_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_SECOND_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_THIRD_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_FOURTH_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_FIFTH_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_SIXTH_ADDRESS
            ],
            [
                UNLOCK_FIRST_TIME,
                UNLOCK_SECOND_TIME,
                UNLOCK_THIRD_TIME,
                UNLOCK_FOURTH_TIME,
                UNLOCK_FIFTH_TIME,
                UNLOCK_SIXTH_TIME,
                UNLOCK_SEVEN_TIME,
                UNLOCK_EIGHT_TIME,
                UNLOCK_NINE_TIME,
                UNLOCK_TEN_TIME
            ]
        );
        console.log(myTx.tx);
    })


}