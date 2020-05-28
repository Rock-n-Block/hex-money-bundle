/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * truffleframework.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */


const HDWalletProvider = require('@truffle/hdwallet-provider');
const infuraKey = "fj4jll3k.....";

const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();

const ganache = require('ganache-core');
const BN = require('bn.js');

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    ganache: {
        network_id: '*', // eslint-disable-line camelcase
        provider: ganache.provider({
            total_accounts: 6, // eslint-disable-line camelcase
            default_balance_ether: new BN(1e+5), // eslint-disable-line camelcase
            mnemonic: 'mywish',
            time: new Date('2020-04-21T12:00:00Z'),
            debug: false,
            // ,logger: console
        }),
    },
    localhost: {
        host: 'localhost',
        port: 8545,
        network_id: '*', // eslint-disable-line camelcase
    },
    ropsten: {
        provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/7a3e8131ad6d42b89d19677154d03008`),
        network_id: 3,       // Ropsten's id
        gas: 5500000,        // Ropsten has a lower block limit than mainnet
        gasPrice: 10000000000,
        //confirmations: 2,    // # of confs to wait between deployments. (default: 0)
        timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
        skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },
    kovan: {
        provider: () => new HDWalletProvider(mnemonic, `https://kovan.infura.io/v3/7ca80e3732bf4b9da67ebd25fa384b20`),
        network_id: 3,       // Ropsten's id
        gas: 5500000,        // Ropsten has a lower block limit than mainnet
        gasPrice: 10000000000,
        //confirmations: 2,    // # of confs to wait between deployments. (default: 0)
        timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
        skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },

  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
       version: "0.6.2",    // Fetch exact version from solc-bin (default: truffle's version)
       docker: false,        // Use "0.5.1" you've installed locally with docker (default: false)
       settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: false,
          runs: 200
        },
        evmVersion: "constantinople"
       }
    }
  }
}
