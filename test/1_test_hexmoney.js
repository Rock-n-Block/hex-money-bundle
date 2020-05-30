const BN = require('bn.js');

require('chai')
    .use(require('chai-bn')(BN))
    .use(require('chai-as-promised'))
    .should();


const { timeTo, increaseTime, revert, snapshot, mine } = require('./utils/evmMethods');
const { web3async, estimateConstructGas } = require('./utils/web3utils');

const {
  // BN,           // Big Number support
  // constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  // expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const HEXToken = artifacts.require('./mocks/HEX.sol')
const HXYToken = artifacts.require('./mocks/HXY.sol')
const HEXMoney = artifacts.require('./HexMoneyContract.sol')
const HEXWhitelist = artifacts.require("./HexWhitelist.sol")


contract('Credit', accounts => {
    const OWNER = accounts[0];
    const ACCOUNT_1 = accounts[1];
    const BUYER_1 = accounts[2];
    const BUYER_2 = accounts[3];
    const HXY_TEAM_ADDRESS = accounts[5];

    const eth = web3.utils.toWei('1', 'ether');
    const day = 86400;

    let now;
    let snapshotId;

    const getBlockchainTimestamp = async () => {
        const latestBlock = await web3async(web3.eth, web3.eth.getBlock, 'latest');
        return latestBlock.timestamp;
    };

    beforeEach(async () => {
        snapshotId = (await snapshot()).result;
        now = await getBlockchainTimestamp();

        hxyTeamTokenAmount = (12 * 10 ** 14).toString();
        hxyTeamTimeLock = (365).toString();
        hexToken = await HEXToken.new(OWNER, hxyTeamTokenAmount);
        hxyToken = await HXYToken.new(HXY_TEAM_ADDRESS, hxyTeamTimeLock);
        hexWhitelist = await HEXWhitelist.new();
        (await hxyToken.balanceOf(HXY_TEAM_ADDRESS)).should.be.bignumber.equal(new BN(hxyTeamTokenAmount));
        hexMoney = await HEXMoney.new(hexToken.address, hxyToken.address, OWNER);
        await hxyToken.setExchange(hexMoney.address);
        //await hxyToken.approve(hexMoney.address, hxyWalletAmount, {from: HXY_TOKEN_WALLET});
        //(await hxyToken.allowance(HXY_TOKEN_WALLET, hexMoney.address)).should.be.bignumber.equal(hxyWalletAmount);
    });

    afterEach(async () => {
        await revert(snapshotId);
    });

    /*
    it('#0 gas usage', async () => {
        await estimateConstructGas(Credit)
            .then(console.info);
    });
    */

    /*
    it('#0 balances', () => {
        accounts.forEach((account, index) => {
            web3.eth.getBalance(account, function (_, balance) {
                const etherBalance = web3.utils.fromWei(balance, 'ether');
                console.info(`Account ${index} (${account}) balance is ${etherBalance}`);
            });
        });
    });


    it('#1 construct', async () => {
        hexMoney.address.should.have.length(42);
        await hexMoney.getHexTokenAddress().should.eventually.have.length(42);
        await hexMoney.getHxyTokenAddress().should.eventually.have.length(42);
        (await hexMoney.getHexTokenAddress()).should.be.equal(hexToken.address);
        (await hexMoney.getHxyTokenAddress()).should.be.equal(hxyToken.address);
    });

    it('#2 check base values', async () => {
        currentRate = await hxyToken.getCurrentHxyRate();
        currentRate.should.be.bignumber.equal(new BN(10 ** 3));
        remainingHxyInRound  = await hxyToken.getRemainingHxyInRound();
        remainingHxyInRound.should.be.bignumber.equal(new BN(750 * 10 ** 3))
    })


    it('#3 check basic exchange', async () => {
        const hexAmount = new BN(10 ** 3);
        const hxyAmount = new BN(1);
        await hexToken.mint(BUYER_1, hexAmount);
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_1);
        hexBalanceBefore.should.be.bignumber.equal(hexAmount);

        await hexToken.approve(hexMoney.address, hexAmount, {from: BUYER_1});
        await hexMoney.exchangeHex(hexAmount.toString(), {from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        hexBalanceAfter.should.be.bignumber.equals(hexBalanceBefore.sub(hexAmount));
        (await hxyToken.balanceOf(BUYER_1)).should.be.bignumber.equals(hxyAmount);
    })

    it('#4 check rate round switching', async () => {
        const expectedFirstRoundRate = new BN(10 ** 3);
        const expectedSecondRoundRate = expectedFirstRoundRate.mul(new BN(2));
        const firstRoundRate = await hxyToken.getCurrentHxyRate();
        firstRoundRate.should.be.bignumber.equal(expectedFirstRoundRate);
        const firstRoundAmount = (await hxyToken.getRemainingHxyInRound()).mul(firstRoundRate);

        // first round
        await hexToken.mint(BUYER_1, firstRoundAmount.toString());
        const firstRoundBalanceBefore = await hexToken.balanceOf(BUYER_1);
        firstRoundBalanceBefore.should.be.bignumber.equal(firstRoundAmount);

        await hexToken.approve(hexMoney.address, firstRoundAmount.toString(), {from: BUYER_1});
        await hexMoney.exchangeHex(firstRoundAmount.toString(), {from: BUYER_1}).should.not.be.rejected;

        const firstRoundBalanceAfter = await hexToken.balanceOf(BUYER_1);
        firstRoundBalanceAfter.should.be.bignumber.equals(firstRoundBalanceBefore.sub(firstRoundAmount));

        const firstHxyAmount = firstRoundAmount.div(firstRoundRate);
        const firstHxyBalance = await hxyToken.balanceOf(BUYER_1);
        firstHxyBalance.should.be.bignumber.equals(firstHxyAmount)

        // validate switching
        const secondRoundRate = await hxyToken.getCurrentHxyRate();
        secondRoundRate.should.be.bignumber.equal(expectedSecondRoundRate);
        const remainingInFirstRound = await hxyToken.getRemainingHxyInRound();
        remainingInFirstRound.should.be.bignumber.equals(new BN(425 * 10 ** 4));

        // second round
        const secondRoundAmount = expectedSecondRoundRate;
        await hexToken.mint(BUYER_2, secondRoundAmount.toString());
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_2);
        hexBalanceBefore.should.be.bignumber.equal(secondRoundAmount);

        await hexToken.approve(hexMoney.address, secondRoundAmount.toString(), {from: BUYER_2});
        await hexMoney.exchangeHex(secondRoundAmount.toString(), {from: BUYER_2}).should.not.be.rejected;

        const secondHxyAmount = secondRoundAmount.div(secondRoundRate);
        (await hxyToken.balanceOf(BUYER_2)).should.be.bignumber.equals(secondHxyAmount);
    })

     */

    it('#5 check dividends if freezed', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexMoney.address, hexAmount.toString(), {from: BUYER_1});
        await hexMoney.exchangeHex(hexAmount.toString(), {from: BUYER_1}).should.not.be.rejected;

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);
        const freezeTime = (await getBlockchainTimestamp()) + (10 * day);
        await hxyToken.freezeHxy(hxyBalance.toString(), freezeTime, {from: BUYER_1}).should.not.be.rejected;

        await increaseTime(day + 10);
        await hexMoney.claimDividends({from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        const dividendsPercent = await hexMoney.getHexDividendsPercentage();
        hexBalanceAfter.should.be.bignumber.equals(new BN(hexAmount * dividendsPercent / 100));
    })

    it('#6 check dividends if not freezed', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);

        await hexToken.mint(BUYER_1, hexAmount.toString());

        await hexToken.approve(hexMoney.address, hexAmount.toString(), {from: BUYER_1});
        await hexMoney.exchangeHex(hexAmount.toString(), {from: BUYER_1}).should.not.be.rejected;

        await increaseTime(day + 10);

        await hexMoney.claimDividends({from: BUYER_1}).should.be.rejected;
    })
});