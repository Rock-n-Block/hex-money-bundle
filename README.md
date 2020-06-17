## HXY Money Contracts

### Install dependencies
```bash
yarn install
```

### Compile:
```bash
yarn compile
```

Before running tests or deplying contracts to public networks, copy `.env.example` to `.env` file and adjust parameters for your needs.
Current parameters in example file was used at a time when HEX Money was deployed to mainnet. 

### Test:
```bash
cp .env.example .env
yarn test
```

### Deploy:

In order to deploy contracts to public network, these parateres must be specified in `.env` file:
 1. `DEPLOYER_MNEMONIC` - private key or seed of deployer account
 2. `INFURA_ROPSTEN` or `INFURA_KOVAN` or `INFURA_MAINNET` - Infura endpoints for web3

```bash
cp .env.example .env
```

Deploy to Ropsten:
```bash
yarn deploy-ropsten
``` 

Deploy to Kovan:
```bash
yarn deploy-kovan
``` 