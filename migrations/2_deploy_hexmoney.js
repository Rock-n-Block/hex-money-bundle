const WhitelistLib = artifacts.require('./WhitelistLib.sol');
const HexToken = artifacts.require('./mocks/HEX.sol');
const HxyToken = artifacts.require('./token/HXY.sol');

const HexWhitelist = artifacts.require('./HexWhitelist.sol');
const HexMoney = artifacts.require('./HexMoneyContract.sol');

module.exports = async function (deployer, network, accounts) {
    const owner = accounts[0];
    const tokenTeamLock = 365;
    await deployer.deploy(WhitelistLib);
    await deployer.link(WhitelistLib, HexWhitelist);
    await deployer.link(WhitelistLib, HxyToken);
    await deployer.link(WhitelistLib, HexMoney);
    let hexToken = await deployer.deploy(HexToken, owner, (10 ** 16).toString());

    let whitelist = await deployer.deploy(HexWhitelist)
    let hxyToken = await deployer.deploy(HxyToken, owner, tokenTeamLock);

    let hexContract = await deployer.deploy(HexMoney, hexToken.address, hxyToken.address);


}

// module.exports = function (deployer, network, accounts) {
//     const owner = accounts[0]
//     const tokenTeamLock = (15778800).toString();
//     return deployer.deploy(HEXToken, owner, (10 ** 20).toString())
//         .then(hexToken => {
//             return deployer.deploy(HXYToken, owner, tokenTeamLock)
//                 .then(hxyToken => {
//                     return deployer.deploy()
//                     // return deployer.deploy(HexMoney, hexToken.address, hxyToken.address)
//                 })
//         })
// }