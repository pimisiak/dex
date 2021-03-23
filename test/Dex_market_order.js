const Dex = artifacts.require("Dex");
const Link = artifacts.require("Link");

const truffleAssert = require('truffle-assertions');

contract("Dex", accounts => {
    let dex;
    let link;
    let linkTicker;
    let ethTicker;

    before(async() => {
        dex = await Dex.deployed();
        link = await Link.deployed();
        linkTicker = web3.utils.fromUtf8("LINK");
        await dex.addToken(linkTicker, link.address, {from: accounts[0]})
        ethTicker = web3.utils.fromUtf8("ETH");
    });

    it("should throw an error if token balance is less than SELL market order amount", async() => {
        let balance = await dex.balances(accounts[4], linkTicker)
        assert.equal(balance.toNumber(), 0, "Initial LINK balance is not 0");
        await truffleAssert.reverts(
            dex.createMarketOrder(1, linkTicker, 1)
        );
    });
    
    it("should be possible to create market order even if the order book is empty", async() => {
        await dex.depositEth({value: 50000});
        let buyOrderBook = await dex.getOrderBook(linkTicker, 0);
        assert(buyOrderBook.length == 0, "BUY order book length is not equal to 0");
        await truffleAssert.passes(
            dex.createMarketOrder(0, linkTicker, 10)
        );
    });
    
    it("market orders should not fill more limit orders than the market order amount", async () => {
        let sellOrderBook = await dex.getOrderBook(linkTicker, 1);
        assert(sellOrderBook.length == 0, "SELL order book should be empty at start of test");

        //Send LINK tokens to accounts 1, 2, 3 from account 0
        await link.transfer(accounts[1], 150)
        await link.transfer(accounts[2], 150)
        await link.transfer(accounts[3], 150)

        //Approve DEX for accounts 1, 2, 3
        await link.approve(dex.address, 50, {from: accounts[1]});
        await link.approve(dex.address, 50, {from: accounts[2]});
        await link.approve(dex.address, 50, {from: accounts[3]});

        //Deposit LINK into DEX for accounts 1, 2, 3
        await dex.deposit(50, linkTicker, {from: accounts[1]});
        await dex.deposit(50, linkTicker, {from: accounts[2]});
        await dex.deposit(50, linkTicker, {from: accounts[3]});

        //Fill up the sell order book
        await dex.createLimitOrder(1, linkTicker, 5, 300, {from: accounts[1]})
        await dex.createLimitOrder(1, linkTicker, 5, 400, {from: accounts[2]})
        await dex.createLimitOrder(1, linkTicker, 5, 500, {from: accounts[3]})

        //Create market order that should fill 2/3 orders in the book
        await dex.createMarketOrder(0, linkTicker, 10);

        sellOrderBook = await dex.getOrderBook(linkTicker, 1);
        assert(sellOrderBook.length == 1, "SELL order book should only have 1 order left");
        assert(sellOrderBook[0].filled == 0, "SELL order should have 0 filled");

    })

    it("market orders should be filled until the order book is empty", async () => {
        let sellOrderBook = await dex.getOrderBook(linkTicker, 1);
        assert(sellOrderBook.length == 1, "SELL orderbook should have 1 order left");

        //Fill up the sell order book again
        await dex.createLimitOrder(1, linkTicker, 5, 400, {from: accounts[1]})
        await dex.createLimitOrder(1, linkTicker, 5, 500, {from: accounts[2]})

        //check buyer link balance before link purchase
        let balanceBefore = await dex.balances(accounts[0], linkTicker)

        //Create market order that could fill more than the entire order book (15 link)
        await dex.createMarketOrder(0, linkTicker, 50);

        //check buyer link balance after link purchase
        let balanceAfter = await dex.balances(accounts[0], linkTicker)

        //Buyer should have 15 more link after, even though order was for 50. 
        assert.equal(balanceBefore.toNumber() + 15, balanceAfter.toNumber());
    })

    it("eth balance of the buyer should decrease with the filled amount", async () => {
        //Seller deposits link and creates a sell limit order for 1 link for 300 wei
        await link.approve(dex.address, 500, {from: accounts[1]});
        await dex.createLimitOrder(1, linkTicker, 1, 300, {from: accounts[1]})

        //Check buyer ETH balance before trade
        let balanceBefore = await dex.balances(accounts[0], ethTicker);
        await dex.createMarketOrder(0, linkTicker, 1);
        let balanceAfter = await dex.balances(accounts[0], ethTicker);

        assert.equal(balanceBefore.toNumber() - 300, balanceAfter.toNumber());
    })

    it("token balances of the limit order sellers should decrease with the filled amounts.", async () => {
        let sellOrderbook = await dex.getOrderBook(linkTicker, 1); 
        assert(sellOrderbook.length == 0, "SELL orderbook should be empty at start of test");

        //Seller Account[2] deposits link
        await link.approve(dex.address, 500, {from: accounts[2]});
        await dex.deposit(100, linkTicker, {from: accounts[2]});

        await dex.createLimitOrder(1, linkTicker, 1, 300, {from: accounts[1]})
        await dex.createLimitOrder(1, linkTicker, 1, 400, {from: accounts[2]})

        //Check sellers Link balances before trade
        let account1balanceBefore = await dex.balances(accounts[1], linkTicker);
        let account2balanceBefore = await dex.balances(accounts[2], linkTicker);

        //Account[0] created market order to buy up both sell orders
        await dex.createMarketOrder(0, linkTicker, 2);

        //Check sellers Link balances after trade
        let account1balanceAfter = await dex.balances(accounts[1], linkTicker);
        let account2balanceAfter = await dex.balances(accounts[2], linkTicker);

        assert.equal(account1balanceBefore.toNumber() - 1, account1balanceAfter.toNumber());
        assert.equal(account2balanceBefore.toNumber() - 1, account2balanceAfter.toNumber());
    })

    it("filled limit orders should be removed from the orderbook", async () => {
        //Seller deposits link and creates a sell limit order for 1 link for 300 wei
        await link.approve(dex.address, 500);
        await dex.deposit(50, linkTicker);
        await dex.depositEth({value: 10000});

        let sellOrderBook = await dex.getOrderBook(linkTicker, 1);

        await dex.createLimitOrder(1, linkTicker, 1, 300)
        await dex.createMarketOrder(0, linkTicker, 1);

        sellOrderBook = await dex.getOrderBook(linkTicker, 1);
        assert(sellOrderBook.length == 0, "SELL orderbook should be empty after trade");
    })

    it("limit orders filled property should be set correctly after a trade", async () => {
        let sellOrderBook = await dex.getOrderBook(linkTicker, 1);
        assert(sellOrderBook.length == 0, "SELL orderbook should be empty at start of test");

        await dex.createLimitOrder(1, linkTicker, 5, 300, {from: accounts[1]})
        await dex.createMarketOrder(0, linkTicker, 2);

        sellOrderBook = await dex.getOrderBook(linkTicker, 1);
        assert.equal(sellOrderBook[0].filled, 2);
        assert.equal(sellOrderBook[0].amount, 5);
    })

    //When creating a BUY market order, the buyer needs to have enough ETH for the trade
    it("should throw an error if eth balance is less than BUY market order amount", async () => {
        let balance = await dex.balances(accounts[4], ethTicker)
        assert.equal(balance.toNumber(), 0, "Initial ETH balance is not 0");
        await dex.createLimitOrder(1, linkTicker, 5, 300, {from: accounts[1]})
        await truffleAssert.reverts(
            dex.createMarketOrder(0, linkTicker, 5, {from: accounts[4]})
        )
    })
})