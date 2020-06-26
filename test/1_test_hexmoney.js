const BN = require('bn.js');

require('chai')
    .use(require('chai-bn')(BN))
    .use(require('chai-as-promised'))
    .should();

require('dotenv').config({ path: '../.env' })

const { timeTo, increaseTime, revert, snapshot, mine } = require('./utils/evmMethods');
const { web3async, estimateConstructGas } = require('./utils/web3utils');

const {
  // BN,           // Big Number support
  // constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  // expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const HXYToken = artifacts.require('./token/HXY.sol')
const HEXToken = artifacts.require('./mocks/HEX.sol')
const USDCToken = artifacts.require('./mocks/USDC.sol')
const HEXWhitelist = artifacts.require("./whitelist/HexWhitelist.sol")
const HEXDividends = artifacts.require('./HexMoneyDividends.sol');
const HEXExchangeHEX = artifacts.require('./exchange/HexMoneyExchangeHEX.sol');
const HEXExchangeETH = artifacts.require('./exchange/HexMoneyExchangeETH.sol');
const HEXExchangeReferral = artifacts.require('./exchange/HexMoneyReferralSender.sol');

const UniswapV1 = artifacts.require('UniswapV1');
const UniswapExchangeAmountGettersV1 = artifacts.require('UniswapExchangeAmountGettersV1',);


contract('exchange', accounts => {
    const OWNER = accounts[0];
    const ACCOUNT_1 = accounts[1];
    const BUYER_1 = accounts[2];
    const BUYER_2 = accounts[3];
    const BUYER_3 = accounts[3];
    const HXY_TEAM_ADDRESS = accounts[5];
    const HXY_LOCKED_ADDRESS = accounts[6];
    const HXY_LIQUID_ADDRESS = accounts[7];
    const HXY_MIGRATED_ADDRESS = accounts[8];
    const HXY_DIVIDENDS_TEAM_FIRST = accounts[9];
    const HXY_DIVIDENDS_TEAM_SECOND = accounts[10];
    const HXY_DIVIDENDS_TEAM_THIRD = accounts[11];
    const HXY_DIVIDENDS_TEAM_FOURTH = accounts[12];

    const eth = web3.utils.toWei('1', 'ether');
    const day = 86400;
    //const day = 300;

    let now;
    let snapshotId;

    const getBlockchainTimestamp = async () => {
        const latestBlock = await web3async(web3.eth, web3.eth.getBlock, 'latest');
        return latestBlock.timestamp;
    };

    beforeEach(async () => {
        snapshotId = (await snapshot()).result;
        now = await getBlockchainTimestamp();

        hxyTeamTokenAmount = (new BN(12)).mul((new BN(10)).pow(new BN(14)));
        usdcTeamTokenAmount = (new BN(12)).mul((new BN(10)).pow(new BN(24)));
        hxyTeamTimeLock = (365).toString();
        hexWhitelist = await HEXWhitelist.new(OWNER, {from: OWNER});
        //hxyToken = await HXYToken.new(HXY_TEAM_ADDRESS, HXY_LIQUID_ADDRESS, HXY_LOCKED_ADDRESS, HXY_MIGRATED_ADDRESS);

        const {
            HEX_MONEY_LIQUID_SUPPLY_AMOUNT,
            HEX_MONEY_LOCKED_SUPPLY_FIRST_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_SECOND_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_THIRD_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_FOURTH_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_FIFTH_ADDRESS,
            HEX_MONEY_LOCKED_SUPPLY_SIXTH_ADDRESS,
            UNLOCK_FIRST_TIME,
            UNLOCK_SECOND_TIME,
            UNLOCK_THIRD_TIME,
            UNLOCK_FOURTH_TIME,
            UNLOCK_FIFTH_TIME,
            UNLOCK_SIXTH_TIME,
            UNLOCK_SEVEN_TIME,
            UNLOCK_EIGHT_TIME,
            UNLOCK_NINE_TIME,
            UNLOCK_TEN_TIME
        } = process.env

        hxyToken = await HXYToken.new(hexWhitelist.address, HXY_LIQUID_ADDRESS, HEX_MONEY_LIQUID_SUPPLY_AMOUNT);
        await hxyToken.premintLocked(
            [
                HXY_LOCKED_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_SECOND_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_THIRD_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_FOURTH_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_FIFTH_ADDRESS,
                HEX_MONEY_LOCKED_SUPPLY_SIXTH_ADDRESS
            ],
            [
                UNLOCK_FIRST_TIME,
                UNLOCK_SECOND_TIME,
                UNLOCK_THIRD_TIME,
                UNLOCK_FOURTH_TIME,
                UNLOCK_FIFTH_TIME,
                UNLOCK_SIXTH_TIME,
                UNLOCK_SEVEN_TIME,
                UNLOCK_EIGHT_TIME,
                UNLOCK_NINE_TIME,
                UNLOCK_TEN_TIME
            ]
        );

        hexToken = await HEXToken.new(OWNER, hxyTeamTokenAmount);
        usdcToken = await USDCToken.new(OWNER, usdcTeamTokenAmount);

        const currentTime = new BN(await getBlockchainTimestamp());
        hexDividends = await HEXDividends.new(
            hxyToken.address,
            hexToken.address,
            usdcToken.address,
            HXY_DIVIDENDS_TEAM_FIRST,
            HXY_DIVIDENDS_TEAM_SECOND,
            HXY_DIVIDENDS_TEAM_THIRD,
            currentTime.add(new BN(day))
            );
        referralSander = await HEXExchangeReferral.new(hxyToken.address, hexWhitelist.address, OWNER);
        await hexWhitelist.registerDappNonTradeable(referralSander.address, eth.toString(),30,  {from: OWNER}).should.not.be.rejected;
        (await hexWhitelist.isRegisteredDappOrReferral(referralSander.address)).should.be.true;
        (await hexWhitelist.isRegisteredDapp(referralSander.address)).should.be.true;
        (await hexWhitelist.getDappTradeable(referralSander.address)).should.be.false;

        hexExchangeHEX = await HEXExchangeHEX.new(hxyToken.address, hexToken.address, hexDividends.address, referralSander.address, OWNER);
        await hexWhitelist.registerExchangeTradeable(hexExchangeHEX.address, eth.toString(), {from: OWNER}).should.not.be.rejected;
        (await hexWhitelist.isRegisteredExchange(hexExchangeHEX.address)).should.be.true;
        (await hexWhitelist.getExchangeTradeable(hexExchangeHEX.address)).should.be.true;
    });

    afterEach(async () => {
        await revert(snapshotId);
    });


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

    it('#4 check basic exchange for ETH', async () => {
        const uniswapRate = new BN(`${205209}`, 10);
        const uniswapV1 = await UniswapV1.new(uniswapRate);
        const uniswapProxy = await UniswapExchangeAmountGettersV1.new(uniswapV1.address);


        hexExchangeETH = await HEXExchangeETH.new(hxyToken.address, hexDividends.address, referralSander.address, uniswapProxy.address, OWNER);
        (await hxyToken.getWhitelistAddress()).should.be.equals(hexWhitelist.address);
        await hexWhitelist.registerExchangeTradeable(hexExchangeETH.address, eth.toString(), {from: OWNER}).should.not.be.rejected;
        (await hexWhitelist.isRegisteredExchange(hexExchangeETH.address)).should.be.true;
        (await hexWhitelist.getExchangeTradeable(hexExchangeETH.address)).should.be.true;

        (await hexExchangeETH.getUniswapGetterInstance()).should.be.equals(uniswapProxy.address);

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

    it('#5 check rate round switching', async () => {
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

    it('#6 check rate adjusted if more than remained in round', async () => {
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

    it('#7 check dividends if freezed', async () => {
        const hexAmount = await hexExchangeHEX.getMaxAmount();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_1}).should.not.be.rejected;

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);

        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        await increaseTime(day + 10);

        const tokensReceived = await hexDividends.getTodayDividendsTotal();

        tokensReceived[2].should.be.bignumber.equals(hexAmount);

        const recordTime = await hexDividends.getRecordTime();
        recordTime.should.be.bignumber.below(new BN(await getBlockchainTimestamp()));


        await hexDividends.claimDividends({from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        hexBalanceAfter.should.be.bignumber.equals(hexAmount.mul(new BN(90)).div(new BN(100)));

        const teamFirstAmount = hexAmount.div(new BN(10));
        const hexBalanceTeamFirst = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_FIRST);

        hexBalanceTeamFirst.should.be.bignumber.equals(teamFirstAmount);


    })

    it('#8 check dividends with two claims', async () => {
        const hexAmount = await hexExchangeHEX.getMaxAmount();
        const expectedTotalHex = hexAmount.mul(new BN(2));
        const expectedBalanceUsers = expectedTotalHex.mul(new BN(90)).div(new BN(100)).div(new BN(2));
        const expectedBalanceTeams = expectedTotalHex.div(new BN(10));

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.mint(BUYER_2, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_2});

        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_2}).should.not.be.rejected;

        const hxyBalanceOne = await hxyToken.balanceOf(BUYER_1);
        const hxyBalanceTwo = await hxyToken.balanceOf(BUYER_2);

        await hxyToken.freezeHxy(hxyBalanceOne.toString(), {from: BUYER_1}).should.not.be.rejected;
        await hxyToken.freezeHxy(hxyBalanceTwo.toString(), {from: BUYER_2}).should.not.be.rejected;

        await increaseTime(day + 10);

        const tokensReceived = await hexDividends.getTodayDividendsTotal();
        tokensReceived[2].should.be.bignumber.equals(hexAmount.mul(new BN(2)));

        await hexDividends.claimDividends({from: BUYER_1}).should.not.be.rejected;
        await increaseTime(20);

        const availableDivs = await hexDividends.getAvailableDividends(BUYER_2)
        availableDivs[2].should.be.bignumber.equals(expectedBalanceUsers);

        await hexDividends.claimDividends({from: BUYER_2}).should.not.be.rejected;

        const hexBalanceAfterOne = await hexToken.balanceOf(BUYER_1);
        const hexBalanceAfterTwo = await hexToken.balanceOf(BUYER_1);
        const hexBalanceTeamFirst = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_FIRST);

        hexBalanceAfterOne.should.be.bignumber.equals(expectedBalanceUsers);
        hexBalanceAfterTwo.should.be.bignumber.equals(expectedBalanceUsers);
        hexBalanceTeamFirst.should.be.bignumber.equals(expectedBalanceTeams);
    })

        it('#9 check dividends with one unclaim', async () => {
        const hexAmount = await hexExchangeHEX.getMaxAmount();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.mint(BUYER_2, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_2});

        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_1}).should.not.be.rejected;
        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_2}).should.not.be.rejected;

        const hxyBalanceOne = await hxyToken.balanceOf(BUYER_1);
        const hxyBalanceTwo = await hxyToken.balanceOf(BUYER_2);

        await hxyToken.freezeHxy(hxyBalanceOne.toString(), {from: BUYER_1}).should.not.be.rejected;
        await hxyToken.freezeHxy(hxyBalanceTwo.toString(), {from: BUYER_2}).should.not.be.rejected;

        await increaseTime(day + 10);

        const tokensReceived = await hexDividends.getTodayDividendsTotal();
        tokensReceived[2].should.be.bignumber.equals(hexAmount.mul(new BN(2)));

        await hexDividends.claimDividends({from: BUYER_1}).should.not.be.rejected;

        const recordTimeFirstDay = await hexDividends.getRecordTime();

        const hexBalanceAfterOne = await hexToken.balanceOf(BUYER_1);
        const hexBalanceTeamFirst = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_FIRST);
        const hexBalanceTeamSecond = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_SECOND);

        const expectedTotalHex = hexAmount.mul(new BN(2));
        const expectedBalanceUser = expectedTotalHex.mul(new BN(90)).div(new BN(100)).div(new BN(2));
        const expectedBalanceTeams = expectedTotalHex.div(new BN(10));

        hexBalanceAfterOne.should.be.bignumber.equals(expectedBalanceUser);
        hexBalanceTeamFirst.should.be.bignumber.equals(expectedBalanceTeams);

        // tx for triggering contract and sending unclaimed to second team
        const thirdBuyerAmount = hexAmount.mul(new BN(2));
        await hexToken.mint(BUYER_3, thirdBuyerAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, thirdBuyerAmount.toString(), {from: BUYER_3});
        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_3}).should.not.be.rejected;

        await increaseTime(day + 10);

        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_3}).should.not.be.rejected;

        const recordTimeSecondDay = await hexDividends.getRecordTime();

        recordTimeSecondDay.should.be.bignumber.equals(recordTimeFirstDay.add(new BN(day)));


        const secondHexBalanceTeamFirst = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_FIRST);
        const secondHexBalanceTeamSecond = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_SECOND);
        const secondHexBalanceTeamThird = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_THIRD);

        const secondExpectedBalanceTeamOne = hexAmount.div(new BN(10));
        const secondExpectedBalanceTeamTwo = expectedBalanceUser.mul(new BN(60)).div(new BN(100));
        const secondExpectedBalanceTeamThree = expectedBalanceUser.mul(new BN(40)).div(new BN(100));

        secondHexBalanceTeamFirst.sub(hexBalanceTeamFirst).should.be.bignumber.equals(secondExpectedBalanceTeamOne);
        secondHexBalanceTeamSecond.should.be.bignumber.equals(secondExpectedBalanceTeamTwo);
        secondHexBalanceTeamThird.should.be.bignumber.equals(secondExpectedBalanceTeamThree);
    })

    it('#10 check dividends if not freezed', async () => {
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

    it('#11 check dividends claiming twice', async () => {
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

    it('#12 check dividends if skipped 24h', async () => {
        const hexAmount = await hexExchangeHEX.getMaxAmount();

        await hexToken.mint(BUYER_1, hexAmount.toString());
        await hexToken.approve(hexExchangeHEX.address, hexAmount.toString(), {from: BUYER_1});

        await hexExchangeHEX.exchangeHex(hexAmount.toString(), {from: BUYER_1}).should.not.be.rejected;

        const hxyBalance = await hxyToken.balanceOf(BUYER_1);

        await hxyToken.freezeHxy(hxyBalance.toString(), {from: BUYER_1}).should.not.be.rejected;

        await increaseTime((day * 2) + 10);

        const tokensReceived = await hexDividends.getTodayDividendsTotal();
        tokensReceived[2].should.be.bignumber.equals(hexAmount);
        const recordTime = await hexDividends.getRecordTime();
        recordTime.should.be.bignumber.below(new BN(await getBlockchainTimestamp()));


        await hexDividends.claimDividends({from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        hexBalanceAfter.should.be.bignumber.equals(hexAmount.mul(new BN(90)).div(new BN(100)));

        const teamAmount = hexAmount.div(new BN(10));
        const hexBalanceTeamFirst = await hexToken.balanceOf(HXY_DIVIDENDS_TEAM_FIRST);

        hexBalanceTeamFirst.should.be.bignumber.equals(teamAmount);
    })

    it('#13 check freeze', async () => {
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

    it('#14 check unfreeze', async () => {
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

        const totalMintedBefore = await hxyToken.getTotalHxyMinted();

        await hxyToken.releaseFrozen(freezeStart, {from: BUYER_1}).should.not.be.rejected;

        const unfreezeBalance = await hxyToken.freezingBalanceOf(BUYER_1);
        unfreezeBalance.should.be.bignumber.zero;
        const hxyBalanceAfter = await hxyToken.balanceOf(BUYER_1);
        hxyBalanceAfter.should.be.bignumber.above(hxyBalance);

        const totalMintedAfter = await hxyToken.getTotalHxyMinted();
        totalMintedAfter.should.be.bignumber.equals(totalMintedBefore);
    })

    it('#14 check unfreeze locked', async () => {
        const freezeBalance = await hxyToken.freezingBalanceOf(HXY_LOCKED_ADDRESS)
        freezeBalance.should.not.be.bignumber.zero;

        const userFreezings = await hxyToken.getUserFreezings(HXY_LOCKED_ADDRESS);
        const freezeId = userFreezings[0];
        const freezing = await hxyToken.getFreezingById(freezeId);
        const freezeStart = freezing.startDate;
        const freezeDays = freezing.freezeDays;

        const endFreezeTime = freezeStart.add(freezeDays.mul(new BN(day)).add(new BN(10)));
        await timeTo(endFreezeTime);

        const freezeBalanceBefore = await hxyToken.freezingBalanceOf(HXY_LOCKED_ADDRESS);
        await hxyToken.releaseFrozen(freezeStart, {from: HXY_LOCKED_ADDRESS}).should.not.be.rejected;

        const freezeBalanceAfter = await hxyToken.freezingBalanceOf(HXY_LOCKED_ADDRESS);

        freezeBalanceAfter.should.be.bignumber.below(freezeBalanceBefore);
    })

    it('#15 check refreeze', async () => {
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

        const latestFreezing = await hxyToken.latestFreezeTimeOf(BUYER_1);
        latestFreezing.should.be.bignumber.equals(new BN(await getBlockchainTimestamp()));

        await timeTo(freezeTime +1);

        const userFreezings = await hxyToken.getUserFreezings(BUYER_1);
        const freezeId = userFreezings[0];
        const freezing = await hxyToken.getFreezingById(freezeId);
        const freezeStart = freezing.startDate;

        const freezeBalanceSecond = await hxyToken.freezingBalanceOf(BUYER_1);

        await hxyToken.refreezeHxy(freezeStart, {from: BUYER_1}).should.not.be.rejected;
        const refreezeBalance = await hxyToken.freezingBalanceOf(BUYER_1);
        refreezeBalance.should.be.bignumber.above(freezeBalanceSecond)

        const userFreezingsAfter = await hxyToken.getUserFreezings(BUYER_1);
        const newFreezeId = userFreezingsAfter[0];


        newFreezeId.should.not.be.equals(freezeId);
        const freezingAfter = await hxyToken.getFreezingById(newFreezeId);
        const freezeStartAfter = freezingAfter.startDate;

        freezeStartAfter.should.be.bignumber.above(freezeStart);
        const latestFreezingAfter = await hxyToken.latestFreezeTimeOf(BUYER_1);
        latestFreezingAfter.should.be.bignumber.equals(new BN(await getBlockchainTimestamp()));
        latestFreezingAfter.should.be.bignumber.above(latestFreezing);

    })


    it('#16 check refreeze after refreeze', async () => {
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

        const latestFreezing = await hxyToken.latestFreezeTimeOf(BUYER_1);
        latestFreezing.should.be.bignumber.equals(new BN(await getBlockchainTimestamp()));

        await timeTo(freezeTime +1);

        const userFreezings = await hxyToken.getUserFreezings(BUYER_1);
        const freezeId = userFreezings[0];
        const freezing = await hxyToken.getFreezingById(freezeId);
        const freezeStart = freezing.startDate;

        const freezeBalanceSecond = await hxyToken.freezingBalanceOf(BUYER_1);

        await hxyToken.refreezeHxy(freezeStart, {from: BUYER_1}).should.not.be.rejected;
        const refreezeBalance = await hxyToken.freezingBalanceOf(BUYER_1);
        refreezeBalance.should.be.bignumber.above(freezeBalanceSecond)

        const userFreezingsAfter = await hxyToken.getUserFreezings(BUYER_1);
        const newFreezeId = userFreezingsAfter[0];

        const prevFreezing = await hxyToken.getFreezingById(freezeId);
        prevFreezing.freezeAmount.should.be.bignumber.zero;

        newFreezeId.should.not.be.equals(freezeId);
        const freezingAfter = await hxyToken.getFreezingById(newFreezeId);
        const freezeStartAfter = freezingAfter.startDate;

        freezeStartAfter.should.be.bignumber.above(freezeStart);
        const latestFreezingAfter = await hxyToken.latestFreezeTimeOf(BUYER_1);
        latestFreezingAfter.should.be.bignumber.equals(new BN(await getBlockchainTimestamp()));
        latestFreezingAfter.should.be.bignumber.above(latestFreezing);

        await increaseTime(day + 5)

        await hxyToken.refreezeHxy(freezeStartAfter, {from: BUYER_1}).should.not.be.rejected;

        //const userFreezingsAfterTwo = await hxyToken.getUserFreezings(BUYER_1);

        const afterCapitalizeFreezing = await hxyToken.getFreezingById(newFreezeId);
        afterCapitalizeFreezing.freezeAmount.should.be.bignumber.zero;

    })

    it('#17 check buy with referral', async () => {
        const hexAmount = new BN(2 * 10 ** 11);
        const hxyAmount = new BN(10 ** 8);
        await hexToken.mint(BUYER_1, hexAmount);
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_1);
        hexBalanceBefore.should.be.bignumber.equal(hexAmount);
        hxyBalanceReferralBefore = await hxyToken.balanceOf(BUYER_3);

        await hexToken.approve(hexExchangeHEX.address, hexAmount, {from: BUYER_1});
        await hexExchangeHEX.exchangeHexWithReferral(hexAmount.toString(), BUYER_3, {from: BUYER_1}).should.not.be.rejected;

        const hexBalanceAfter = await hexToken.balanceOf(BUYER_1);
        hexBalanceAfter.should.be.bignumber.equals(hexBalanceBefore.sub(hexAmount));
        (await hxyToken.balanceOf(BUYER_1)).should.be.bignumber.equals(hxyAmount);

        hxyBalanceReferralAfter = await hxyToken.balanceOf(BUYER_3);
        hxyBalanceReferralAfter.should.be.bignumber.above(hxyBalanceReferralBefore)

        const refPercent = await referralSander.getReferralPercentage();
        const expectedAmount = hxyAmount.mul(refPercent).div(new BN(100));
        hxyBalanceReferralAfter.should.be.bignumber.equals(expectedAmount);
    });

    it('#18 check change referral percentage', async () => {
        const hexAmount = new BN(2 * 10 ** 11);
        const hxyAmount = new BN(10 ** 8);
        await hexToken.mint(BUYER_1, hexAmount);
        const hexBalanceBefore = await hexToken.balanceOf(BUYER_1);
        hexBalanceBefore.should.be.bignumber.equal(hexAmount);
        hxyBalanceReferralBefore = await hxyToken.balanceOf(BUYER_3);

        const refPercent = await referralSander.getReferralPercentage();
        const expectedAmount = hxyAmount.mul(refPercent).div(new BN(100));
        hxyBalanceReferralAfter.should.be.bignumber.equals(expectedAmount);

        await referralSander.setReferralPercentage(10, {from: BUYER_1}).should.be.rejected;
        await referralSander.setReferralPercentage(1000, {from: OWNER}).should.be.rejected;
        await referralSander.setReferralPercentage(10, {from: OWNER}).should.not.be.rejected;

        const refPercentChanged = await referralSander.getReferralPercentage();
        refPercentChanged.should.not.be.bignumber.equals(refPercent);
        refPercentChanged.should.be.bignumber.equals(new BN(10));

        hxyBalanceReferralChangedBefore = await hxyToken.balanceOf(BUYER_2);
        await hexToken.approve(hexExchangeHEX.address, hexAmount, {from: BUYER_1});
        await hexExchangeHEX.exchangeHexWithReferral(hexAmount.toString(), BUYER_2, {from: BUYER_1}).should.not.be.rejected;

        hxyBalanceReferralChangedAfter = await hxyToken.balanceOf(BUYER_2);

        const expectedAmountChanged = hxyAmount.mul(refPercent).div(new BN(100));
        hxyBalanceReferralAfter.should.be.bignumber.equals(expectedAmountChanged);
    })

});
