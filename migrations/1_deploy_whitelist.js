require('dotenv').config({ path: '../.env' })

const HxyToken = artifacts.require('./token/HXY.sol');

const WhitelistLib = artifacts.require('./whitelist/WhitelistLib.sol');
const HexWhitelist = artifacts.require('./whitelist/HexWhitelist.sol');

module.exports = async function (deployer, network, accounts) {

    // // STAGE 1
    return deployer.then(async () => {
        await deployer.deploy(WhitelistLib);
        await deployer.link(WhitelistLib, HexWhitelist);
        await deployer.link(WhitelistLib, HxyToken);

        const { ADMIN_ROLE_ADDRESS } = process.env

        console.log('Admin address: ', ADMIN_ROLE_ADDRESS)

        const hexWhitelist = await deployer.deploy(HexWhitelist, ADMIN_ROLE_ADDRESS);
        console.log('HEX Whitelist address: ', hexWhitelist.address);
    })



}