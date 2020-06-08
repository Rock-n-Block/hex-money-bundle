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
const HXYToken = artifacts.require('./token/HXY.sol')
const HEXWhitelist = artifacts.require("./whitelist/HexWhitelist.sol")
const HEXDividends = artifacts.require('./HexMoneyDividends.sol');
const HEXExchangeHEX = artifacts.require('./exchange/HexMoneyExchangeHEX.sol');
const HEXExchangeETH = artifacts.require('./exchange/HexMoneyExchangeETH.sol');

const UniswapV1 = artifacts.require('UniswapV1');
const UniswapExchangeAmountGettersV1 = artifacts.require('UniswapExchangeAmountGettersV1',);


contract('hxy', accounts => {
    const OWNER = accounts[0];
    const ACCOUNT_1 = accounts[1];
    const BUYER_1 = accounts[2];
    const BUYER_2 = accounts[3];
    const HXY_TEAM_ADDRESS = accounts[5];
    const HXY_LOCKED_ADDRESS = accounts[6];
    const HXY_LIQUID_ADDRESS = accounts[7];
    const HXY_MIGRATED_ADDRESS = accounts[8];
    const HXY_DIVIDENDS_TEAM = accounts[9];
    const HXY_DIVIDENDS_TEAM_TWO = accounts[10];

    const eth = web3.utils.toWei('1', 'ether');
    //const day = 86400;
    const day = 120;

    let now;
    let snapshotId;

    const getBlockchainTimestamp = async () => {
        const latestBlock = await web3async(web3.eth, web3.eth.getBlock, 'latest');
        return latestBlock.timestamp;
    };

    beforeEach(async () => {
        snapshotId = (await snapshot()).result;
        now = await getBlockchainTimestamp();

    });

    afterEach(async () => {
        await revert(snapshotId);
    });


    it('#1 construct', async () => {
        hxyToken = await HXYToken.new(HXY_TEAM_ADDRESS, HXY_LIQUID_ADDRESS, HXY_LOCKED_ADDRESS, HXY_MIGRATED_ADDRESS).should.not.be.rejected;

        hxyTeamTokenAmount = (12 * 10 ** 14).toString();
        hxyLockedAmount = (6 * 10 ** 14).toString();
        (await hxyToken.balanceOf(HXY_TEAM_ADDRESS)).should.be.bignumber.equal(new BN(hxyTeamTokenAmount));
        (await hxyToken.getLockedSupply()).should.be.bignumber.equal(new BN(hxyLockedAmount));
    });
})



contract('exchange', accounts => {
    const OWNER = accounts[0];
    const ACCOUNT_1 = accounts[1];
    const BUYER_1 = accounts[2];
    const BUYER_2 = accounts[3];
    const HXY_TEAM_ADDRESS = accounts[5];
    const HXY_LOCKED_ADDRESS = accounts[6];
    const HXY_LIQUID_ADDRESS = accounts[7];
    const HXY_MIGRATED_ADDRESS = accounts[8];
    const HXY_DIVIDENDS_TEAM = accounts[9];
    const HXY_DIVIDENDS_TEAM_TWO = accounts[10];

    const eth = web3.utils.toWei('1', 'ether');
    //const day = 86400;
    const day = 120;

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
        hxyToken = await HXYToken.new(HXY_TEAM_ADDRESS, HXY_LIQUID_ADDRESS, HXY_LOCKED_ADDRESS, HXY_MIGRATED_ADDRESS);
        hexWhitelist = await HEXWhitelist.new({from: OWNER});
        (await hxyToken.balanceOf(HXY_TEAM_ADDRESS)).should.be.bignumber.equal(new BN(hxyTeamTokenAmount));
        //(await hxyToken.getLockedSupply()).should.be.bignumber.equal(new BN(hxyLockedAmount));
        hexDividends = await HEXDividends.new(hexToken.address, hxyToken.address, HXY_DIVIDENDS_TEAM, HXY_DIVIDENDS_TEAM_TWO);
        hexExchangeHEX = await HEXExchangeHEX.new(hexToken.address, hxyToken.address, hexDividends.address);
        await hxyToken.setWhitelistAddress(hexWhitelist.address).should.not.be.rejected;
        await hexWhitelist.registerDappTradeable(hexExchangeHEX.address, eth.toString(), {from: OWNER}).should.not.be.rejected;
        (await hexWhitelist.isRegisteredDapp(hexExchangeHEX.address)).should.be.true;
        (await hexWhitelist.getDappTradeable(hexExchangeHEX.address)).should.be.true;
        //await hxyToken.setExchange(hexExchangeHEX.address);
        //await hxyToken.approve(hexExchangeHEX.address, hxyWalletAmount, {from: HXY_TOKEN_WALLET});
        //(await hxyToken.allowance(HXY_TOKEN_WALLET, hexExchangeHEX.address)).should.be.bignumber.equal(hxyWalletAmount);
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

    it('#0 balances', () => {
        accounts.forEach((account, index) => {
            web3.eth.getBalance(account, function (_, balance) {
                const etherBalance = web3.utils.fromWei(balance, 'ether');
                console.info(`Account ${index} (${account}) balance is ${etherBalance}`);
            });
        });
    });


    it('#1 construct', async () => {
        hexExchangeHEX.address.should.have.length(42);
        await hexExchangeHEX.getHexTokenAddress().should.eventually.have.length(42);
        await hexExchangeHEX.getHxyTokenAddress().should.eventually.have.length(42);
        (await hexExchangeHEX.getHexTokenAddress()).should.be.equal(hexToken.address);
        (await hexExchangeHEX.getHxyTokenAddress()).should.be.equal(hxyToken.address);
    });

    it('#2 check base values', async () => {
        currentRate = await hxyToken.getCurrentHxyRate();
        currentRate.should.be.bignumber.equal(new BN(2 * 10 ** 3));
        remainingHxyInRound  = await hxyToken.getRemainingHxyInRound();

        remainingHxyInRound.should.be.bignumber.equal(new BN(3 * 10 ** 14))
    })

    it('#3 check basic exchange', async () => {
        const hexAmount = new BN(2 * 10 ** 11);
        const hxyAmount = new BN(10 ** 8);
        await hexToken.mint(BUYER_1, hexAmount);
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_1);
        hexBalanceBefore.should.be.bignumber.equal(hexAmount);

        await hexToken.approve(hexExchangeHEX.address, hexAmount, {from: BUYER_1});
        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        hexBalanceAfter.should.be.bignumber.equals(hexBalanceBefore.sub(hexAmount));
        (await hxyToken.balanceOf(BUYER_1)).should.be.bignumber.equals(hxyAmount);
    })

    it('#3 check basic exchange for ETH', async () => {
        hexExchangeETH = await HEXExchangeETH.new(hxyToken.address, hexDividends.address);
        (await hxyToken.getWhitelistAddress()).should.be.equals(hexWhitelist.address);
        await hexWhitelist.registerDappTradeable(hexExchangeETH.address, eth.toString(), {from: OWNER}).should.not.be.rejected;
        (await hexWhitelist.isRegisteredDapp(hexExchangeETH.address)).should.be.true;
        (await hexWhitelist.getDappTradeable(hexExchangeETH.address)).should.be.true;

        const uniswapRate = new BN(`${205209}`, 10);
        const uniswapV1 = await UniswapV1.new(uniswapRate);
        const uniswapProxy = await UniswapExchangeAmountGettersV1.new(uniswapV1.address);

        await hexExchangeETH.setUniswapGetterInstance(uniswapProxy.address);
        (await hexExchangeETH.getUniswapGetterInstance()).should.be.equals(uniswapProxy.address);
        const hexAmount = await hexExchangeETH.getConvertedAmount(eth.toString());

        //const hxyAmount = new BN(1);
        const balanceBefore = await web3.eth.getBalance(BUYER_1);
        const hxyBalanceBefore = await hxyToken.balanceOf(BUYER_1);

        await hexExchangeETH.sendTransaction({from: BUYER_1, value: eth}).should.not.be.rejected;

        const balanceAfter = await web3.eth.getBalance(BUYER_1);
        balanceAfter.should.be.bignumber.below(balanceBefore);
        const hxyBalanceAfter = await hxyToken.balanceOf(BUYER_1);
        hxyBalanceAfter.should.be.bignumber.above(hxyBalanceBefore);

        const hxySecondBalanceBefore = await hxyToken.balanceOf(BUYER_2);
        await hexExchangeETH.exchangeEth({from: BUYER_2, value: eth}).should.not.be.rejected;
        const hxySecondBalanceAfter = await hxyToken.balanceOf(BUYER_2);
        hxySecondBalanceAfter.should.be.bignumber.above(hxySecondBalanceBefore);

    })

    it('#4 check rate round switching', async () => {
        const expectedFirstRoundRate = new BN(2 * 10 ** 3);
        const expectedSecondRoundRate = new BN(3 * 10 ** 3);
        const firstRoundRate = await hxyToken.getCurrentHxyRate();
        firstRoundRate.should.be.bignumber.equal(expectedFirstRoundRate);
        const firstRoundAmount = (await hxyToken.getRemainingHxyInRound()).mul(firstRoundRate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();

        const sendTransactions = firstRoundAmount.div(maxAmount).toNumber();

        // first round
        await hexToken.mint(BUYER_1, firstRoundAmount.toString());
        const firstRoundBalanceBefore = await hexToken.balanceOf(BUYER_1);
        firstRoundBalanceBefore.should.be.bignumber.equal(firstRoundAmount);

        await hexToken.approve(hexExchangeHEX.address, firstRoundAmount.toString(), {from: BUYER_1});

        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        const firstRoundBalanceAfter = await hexToken.balanceOf(BUYER_1);
        firstRoundBalanceAfter.should.be.bignumber.equals(firstRoundBalanceBefore.sub(firstRoundAmount));

        const firstHxyAmount = firstRoundAmount.div(firstRoundRate);
        const firstHxyBalance = await hxyToken.balanceOf(BUYER_1);
        firstHxyBalance.should.be.bignumber.equals(firstHxyAmount)

        // validate switching
        const secondRoundRate = await hxyToken.getCurrentHxyRate();
        secondRoundRate.should.be.bignumber.equal(expectedSecondRoundRate);
        const remainingInFirstRound = await hxyToken.getRemainingHxyInRound();
        remainingInFirstRound.should.be.bignumber.equals(new BN(3 * 10 ** 14));

        // second round
        const secondRoundAmount = await hexExchangeHEX.getMinAmount();
        await hexToken.mint(BUYER_2, secondRoundAmount.toString());
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_2);
        hexBalanceBefore.should.be.bignumber.equal(secondRoundAmount);

        await hexToken.approve(hexExchangeHEX.address, secondRoundAmount.toString(), {from: BUYER_2});
        await hexExchangeHEX.exchangeHex(secondRoundAmount.toString(), {from: BUYER_2}).should.not.be.rejected;

        const secondHxyAmount = secondRoundAmount.div(secondRoundRate);
        const hxyBalanceAfter = await hxyToken.balanceOf(BUYER_2);
        hxyBalanceAfter.should.be.bignumber.equals(secondHxyAmount);
    })

    it('#5 check rate adjusted if more than remained in round', async () => {
        const firstRoundRate = await hxyToken.getCurrentHxyRate();
        const expectedFirstRoundRate = new BN(2 * 10 ** 3);
        const expectedSecondRoundRate = new BN(3 * 10 ** 3);
        const tokensinFirstRound = await hxyToken.getRemainingHxyInRound()
        const hexAmount = tokensinFirstRound.mul(firstRoundRate);
        const overflowAmount = await hexExchangeHEX.getMaxAmount();
        const sendAmount = hexAmount.add(overflowAmount);
        const firstRoundTotalAmount = await hxyToken.getTotalHxyInRound()
        const firstRoundNumber = await hxyToken.getCurrentHxyRound()
        sendAmount.should.be.bignumber.above(firstRoundTotalAmount);
        firstRoundNumber.should.be.bignumber.zero;

        // first round
        await hexToken.mint(BUYER_1, sendAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, sendAmount.toString(), {from: BUYER_1});

        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();
        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        await hexExchangeHEX.exchangeHex(overflowAmount.toString(), {from: BUYER_1}).should.not.be.rejected;

        const hxyAmountAfter = await hxyToken.balanceOf(BUYER_1);
        const secondRoundNumber = await hxyToken.getCurrentHxyRound()
        secondRoundNumber.should.be.bignumber.equals(new BN(1));

        const secondRoundRate = await hxyToken.getCurrentHxyRate();
        secondRoundRate.should.be.bignumber.equal(expectedSecondRoundRate);

        const expectedAmountFirstRound = hexAmount.div(expectedFirstRoundRate);
        const expectedAmountSecondRound = overflowAmount.div(expectedSecondRoundRate);
        const expectedTotal = expectedAmountFirstRound.add(expectedAmountSecondRound);
        expectedTotal.should.be.bignumber.equals(hxyAmountAfter);
    })

    it('#6 check dividends if freezed', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});


        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);
        const freezeTime = (await getBlockchainTimestamp()) + (10 * day);

        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        await increaseTime(day + 10);
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_1);
        await hexDividends.claimDividends({from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        //const dividendsPercent = await hexDividends.getDividendsPercentage();
        hexBalanceAfter.should.be.bignumber.above(hexBalanceBefore);
    })

    it('#6 check dividends distributed for team', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);
        const freezeTime = (await getBlockchainTimestamp()) + (10 * day);

        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        const recordTime = await hexDividends.getRecordTime();
        await increaseTime(day + 10);
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_1);
        await hexDividends.claimDividends({from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        hexBalanceAfter.should.be.bignumber.above(hexBalanceBefore);


        const hexBalanceTeamBefore = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM);
        const hexBalanceTeamTwoBefore = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_TWO);

        await increaseTime(day + 10);
        await hexDividends.manualCheckUpdateDividends().should.not.be.rejected;

        const hexBalanceTeamAfter = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM);
        const hexBalanceTeamTwoAfter = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_TWO);

        hexBalanceTeamAfter.should.be.bignumber.above(hexBalanceTeamBefore)
        hexBalanceTeamTwoAfter.should.be.bignumber.above(hexBalanceTeamTwoBefore)
    })

    it('#6 check remaining record time', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);
        const freezeTime = (await getBlockchainTimestamp()) + (10 * day);

        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        const blockNow = new BN(await getBlockchainTimestamp());
        const recordTime = await hexDividends.getRecordTime();
        const remainingRecordTime = await hexDividends.getRemainingRecordTime();

        remainingRecordTime.should.be.bignumber.equals(recordTime.sub(blockNow))

        await increaseTime(day + 10);

        const recordTimeInPast = await hexDividends.getRecordTime();
        const remainingRecordTimeAdjusted = await hexDividends.getRemainingRecordTime();
        const blockNowAfter = new BN(await getBlockchainTimestamp());
        const expectedRecordTime = recordTimeInPast.add(new BN(day));

        recordTimeInPast.should.be.bignumber.equals(recordTime);
        remainingRecordTimeAdjusted.should.be.bignumber.equals(expectedRecordTime.sub(blockNowAfter))

        const hexBalanceBefore = await hexToken.balanceOf(BUYER_1);
        await hexDividends.claimDividends({from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        hexBalanceAfter.should.be.bignumber.above(hexBalanceBefore);


        const hexBalanceTeamBefore = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM);
        const hexBalanceTeamTwoBefore = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_TWO);

        await increaseTime(day + 10);
        await hexDividends.manualCheckUpdateDividends().should.not.be.rejected;

        const hexBalanceTeamAfter = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM);
        const hexBalanceTeamTwoAfter = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_TWO);

        hexBalanceTeamAfter.should.be.bignumber.above(hexBalanceTeamBefore)
        hexBalanceTeamTwoAfter.should.be.bignumber.above(hexBalanceTeamTwoBefore)
    })

    it('#7 check dividends if not freezed', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        await increaseTime(day + 10);

        await hexDividends.claimDividends({from: BUYER_1}).should.be.rejected;
    })

    it('#8 check dividends claiming twice', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);
        const freezeTime = (await getBlockchainTimestamp()) + (10 * day);
        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        await increaseTime(day + 10);
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_1);
        await hexDividends.claimDividends({from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        //const dividendsPercent = await hexDividends.getDividendsPercentage();
        hexBalanceAfter.should.be.bignumber.above(hexBalanceBefore);

        await hexDividends.claimDividends({from: BUYER_1}).should.be.rejected;

    })

    it('#8 check freeze', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);
        const freezeTime = (await getBlockchainTimestamp()) + (10 * day);

        const freezeBalance = await hxyToken.freezingBalanceOf(BUYER_1)
        freezeBalance.should.be.bignumber.zero;

        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        const freezeBalanceAfter = await hxyToken.freezingBalanceOf(BUYER_1)
        freezeBalanceAfter.should.be.bignumber.equals(hxyBalance);
    })

    it('#8 check unfreeze', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);
        const freezeTime = (await getBlockchainTimestamp()) + (10 * day);

        const freezeBalance = await hxyToken.freezingBalanceOf(BUYER_1)
        freezeBalance.should.be.bignumber.zero;

        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        const freezeBalanceAfter = await hxyToken.freezingBalanceOf(BUYER_1)
        freezeBalanceAfter.should.be.bignumber.equals(hxyBalance);

        await timeTo(freezeTime +1);

        const userFreezings = await hxyToken.getUserFreezings(BUYER_1);
        const freezeId = userFreezings[0];
        const freezing = await hxyToken.getFreezingById(freezeId);
        const freezeStart = freezing.startDate;

        await hxyToken.releaseFrozen(freezeStart, {from: BUYER_1}).should.not.be.rejected;

        const unfreezeBalance = await hxyToken.freezingBalanceOf(BUYER_1);
        unfreezeBalance.should.be.bignumber.zero;
        const hxyBalanceAfter = await hxyToken.balanceOf(BUYER_1);
        hxyBalanceAfter.should.be.bignumber.above(hxyBalance);

    })

    it('#8 check refreeze', async () => {
        const rate = await hxyToken.getCurrentHxyRate();
        const hexAmount = (await hxyToken.getRemainingHxyInRound()).mul(rate);
        const maxAmount = await hexExchangeHEX.getMaxAmount();
        const sendTransactions = hexAmount.div(maxAmount).toNumber();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        for (let i = 0; i < sendTransactions; i++) {
            await hexExchangeHEX.exchangeHex(maxAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        }

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);
        const freezeTime = (await getBlockchainTimestamp()) + (10 * day);

        const freezeBalance = await hxyToken.freezingBalanceOf(BUYER_1)
        freezeBalance.should.be.bignumber.zero;

        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        const freezeBalanceAfter = await hxyToken.freezingBalanceOf(BUYER_1)
        freezeBalanceAfter.should.be.bignumber.equals(hxyBalance);

        await timeTo(freezeTime +1);

        const userFreezings = await hxyToken.getUserFreezings(BUYER_1);
        const freezeId = userFreezings[0];
        const freezing = await hxyToken.getFreezingById(freezeId);
        const freezeStart = freezing.startDate;

        const frezeBalanceAfter = await hxyToken.freezingBalanceOf(BUYER_1);
        await hxyToken.refreezeHxy(freezeStart, {from: BUYER_1}).should.not.be.rejected;

        const refreezeBalance = await hxyToken.freezingBalanceOf(BUYER_1);
        refreezeBalance.should.be.bignumber.above(frezeBalanceAfter)

    })



});
