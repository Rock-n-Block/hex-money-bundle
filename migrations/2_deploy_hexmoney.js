const HexMoney = artifacts.require('./HexMoneyContract.sol');
const HEXToken = artifacts.require('./mocks/HEX.sol');
const HXYToken = artifacts.require('./token/HXY.sol');

// module.exports = async function (deployer, network, accounts) {
//     const owner = accounts[0];
//     let hexToken = await deployer.deploy(HEXToken, owner, (10 ** 16).toString());
//     let hxyToken = await deployer.deploy(HXYToken, owner, (10 ** 16).toString());
//     console.log(hexToken);
//     await deployer.deploy(HexMoney, hexToken.address, hxyToken.address, owner);
//
//
// }

module.exports = function (deployer, network, accounts) {
    const owner = accounts[0]
    return deployer.deploy(HEXToken, owner, (10 ** 20).toString())
        .then(hexToken => {
            return deployer.deploy(HXYToken, owner)
                .then(hxyToken => {
                    return deployer.deploy(HexMoney, hexToken.address, hxyToken.address)
                })
        })
}