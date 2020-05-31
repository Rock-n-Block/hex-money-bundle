const BN = require('bn.js');

module.exports = {
  ethAmount: new BN(`${1 * 10 ** 18}`, 10),
  tokenAmount: new BN(`${1 * 10 ** 8}`, 10),
  expectedEthAmount: new BN(`${20520900000000}`, 10),
  expectedTokenAmount: new BN(`${4873080615372}`, 10),
  rate: new BN(`${205209}`, 10),
};
