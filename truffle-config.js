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
 * To deploy via Infura you'll need a wallet provider (like truffle-hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config({ path: '.env' })

const {
  DEPLOYER_MNEMONIC,
  ETHERSCAN_API_KEY,
  INFURA_KOVAN,
  INFURA_ROPSTEN,
  INFURA_MAINNET
} = process.env;

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
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    // development: {
    //     host: "127.0.0.1", // Localhost (default: none)
    //     port: 8545, // Standard Ethereum port (default: none)
    //     network_id: "*" // Any network (default: none)
    // },
    coverage: {
      host: 'localhost',
      network_id: '*',
      port: 8554, // <-- If you change this, also set the port option in .solcover.js.
      gas: 0xfffffffffff, // <-- Use this high gas value
      gasPrice: 0x01, // <-- Use this low gas price
    },
    // Another network with more advanced options...
    // advanced: {
    // port: 8777,             // Custom port
    // network_id: 1342,       // Custom network
    // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    // from: <address>,        // Account to send txs from (default: accounts[0])
    // websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // },
    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    ropsten: {
      provider: () =>
        new HDWalletProvider(
          DEPLOYER_MNEMONIC.toString(),
          INFURA_ROPSTEN,
        ),
      network_id: 3, // Ropsten's id
      gas: 7900000, // Ropsten has a lower block limit than mainnet
      gasPrice: 45000000000,  
      //confirmations: 2, // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200, // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true, // Skip dry run before migrations? (default: false for public nets )
    },
    kovan: {
      provider: () =>
        new HDWalletProvider(
          DEPLOYER_MNEMONIC.toString(),
          INFURA_KOVAN,
        ),
      network_id: 42, // Kovan's id
      gas: 4900000, // Ropsten has a lower block limit than mainnet
      gasPrice: 38000000000,  // 20 gwei (in wei) (default: 100 gwei)
      confirmations: 2, // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200, // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true, // Skip dry run before migrations? (default: false for public nets )
    },
    live: {
      provider: () =>
        new HDWalletProvider(
          DEPLOYER_MNEMONIC.toString(),
          INFURA_MAINNET,
        ),
      network_id: 1, // Mainnet's id
      gas: 8000000, // gas block limit
      gasPrice: 43000000000,  // 20 gwei (in wei) (default: 100 gwei)
      confirmations: 2, // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 1000, // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: false, // Skip dry run before migrations? (default: false for public nets )
    },
    ganache: {
      network_id: '*', // eslint-disable-line camelcase
      provider: ganache.provider({
          total_accounts: 15, // eslint-disable-line camelcase
          default_balance_ether: new BN(1e+5), // eslint-disable-line camelcase
          mnemonic: 'mywish',
          time: new Date('2020-04-21T12:00:00Z'),
          debug: false,
	  gasLimit: 9000000,
          // ,logger: console
      }),
      gas: 8500000, // gas block limit
    },
    // Useful for private networks
    // private: {
    // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
    // network_id: 2111,   // This network is yours, in the cloud.
    // production: true    // Treats this network as if it was a public net. (default: false)
    // }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: '0.6.2', // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      optimizer: {
        enabled: true,
        runs: 200,
      },
      //  evmVersion: "byzantium"
      // }
    },
  },
  plugins: [
	  'solidity-coverage',
	  'truffle-plugin-verify'
  ],
  api_keys: {
	  etherscan: ETHERSCAN_API_KEY
  }
};
