const HexToken = artifacts.require('./mocks/HEX.sol');
const HxyToken = artifacts.require('./token/HXY.sol');

const WhitelistLib = artifacts.require('./whitelist/WhitelistLib.sol');
const HexWhitelist = artifacts.require('./whitelist/HexWhitelist.sol');

const HexDividends = artifacts.require('./HexMoneyDividends.sol');
const HexExchangeHEX = artifacts.require('./exchange/HexMoneyExchangeHEX.sol');

module.exports = async function (deployer, network, accounts) {
    const owner = accounts[0];
    const tokenTeamLock = 365;
    await deployer.deploy(WhitelistLib);
    await deployer.link(WhitelistLib, HexWhitelist);
    await deployer.link(WhitelistLib, HxyToken);
    await deployer.link(WhitelistLib, HexDividends);
    let hexToken = await deployer.deploy(HexToken, owner, (10 ** 16).toString());
    let whitelist = await deployer.deploy(HexWhitelist)
    let hxyToken = await deployer.deploy(HxyToken, owner, tokenTeamLock, owner, owner);
    let hexDividends = await deployer.deploy(HexDividends, hexToken.address, hxyToken.address, owner);
    let hexExchangeHex = await deployer.deploy(HexExchangeHEX, hexToken.address, hxyToken.address, hexDividends.address);


}