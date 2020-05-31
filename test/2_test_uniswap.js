const BN = require('bn.js');
const chai = require('chai');
const { expect } = require('chai');
const UniswapV1 = artifacts.require('UniswapV1');
const UniswapExchangeAmountGettersV1 = artifacts.require(
  'UniswapExchangeAmountGettersV1',
);

const {
  ethAmount,
  tokenAmount,
  expectedEthAmount,
  expectedTokenAmount,
  rate,
} = require('../config');

chai.use(require('chai-bn')(BN));

contract('UniswapExchangeAmountGettersV1', (accounts) => {
  const [sender, receiver] = accounts;

  let UniswapV1Instance;
  let UniswapExchangeAmountGettersV1Instance;

  beforeEach('setup contracts instances', async () => {
    UniswapV1Instance = await UniswapV1.new(rate);
    UniswapExchangeAmountGettersV1Instance = await UniswapExchangeAmountGettersV1.new(
      UniswapV1Instance.address,
    );
  });

  it('should set exchange address by constructor', async () => {
    const actualExchange = await UniswapExchangeAmountGettersV1Instance.exchange();
    expect(actualExchange).to.equal(UniswapV1Instance.address);
  });

  it('should get eth to token input price', async () => {
    const ethToTokenInputPrice = await UniswapExchangeAmountGettersV1Instance.getEthToTokenInputPrice(
      ethAmount,
      {
        from: sender,
      },
    );

    expect(ethToTokenInputPrice).to.be.a.bignumber.that.equals(
      expectedTokenAmount,
    );
  });

  it('should get eth to token output price', async () => {
    const ethToTokenOutputPrice = await UniswapExchangeAmountGettersV1Instance.getEthToTokenOutputPrice(
      tokenAmount,
      {
        from: sender,
      },
    );

    expect(ethToTokenOutputPrice).to.be.a.bignumber.that.equals(
      expectedEthAmount,
    );
  });

  it('should get token to eth input price', async () => {
    const ethToTokenOutputPrice = await UniswapExchangeAmountGettersV1Instance.getTokenToEthInputPrice(
      tokenAmount,
      {
        from: sender,
      },
    );

    expect(ethToTokenOutputPrice).to.be.a.bignumber.that.equals(
      expectedEthAmount,
    );
  });

  it('should get token to eth output price', async () => {
    const ethToTokenInputPrice = await UniswapExchangeAmountGettersV1Instance.getTokenToEthOutputPrice(
      ethAmount,
      {
        from: sender,
      },
    );

    expect(ethToTokenInputPrice).to.be.a.bignumber.that.equals(
      expectedTokenAmount,
    );
  });
});
