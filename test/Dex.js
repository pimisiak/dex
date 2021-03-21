const Dex = artifacts.require("Dex");
const Link = artifacts.require("Link");

const truffleAssert = require('truffle-assertions');

contract("Dex", accounts => {
    let dex;
    let link;
    let linkTicker;

    before(async() => {
        dex = await Dex.deployed();
        link = await Link.deployed();
        linkTicker = web3.utils.fromUtf8("LINK");
        await dex.addToken(linkTicker, link.address, {from: accounts[0]})
    });

    it("should throw error if ETH balance is less than BUY limit order amount", async() => {
        await truffleAssert.reverts(
            dex.createLimitOrder(0, linkTicker, 1, 10)
        );
        await dex.depositEth({value: 10});
        await truffleAssert.passes(
            dex.createLimitOrder(0, linkTicker, 1, 10)
        );
    });
    
    it("should throw error if token balance is less than SELL limit order amount", async() => {
        await truffleAssert.reverts(
            dex.createLimitOrder(1, linkTicker, 1, 10)
        );
        await link.approve(dex.address, 1);
        await dex.deposit(1, linkTicker);
        await truffleAssert.passes(
            dex.createLimitOrder(1, linkTicker, 1, 10)
        );
    });

    it("BUY order book should be sorted in increasing manner", async() => {
        await dex.depositEth({value: 500});

        await dex.createLimitOrder(0, linkTicker, 1, 300);
        await dex.createLimitOrder(0, linkTicker, 1, 100);
        await dex.createLimitOrder(0, linkTicker, 1, 200);

        let buyOrderBook = await dex.getOrderBook(linkTicker, 0);
        assert(buyOrderBook.length > 0, "incorrect size of buy order book");
        for (let i = 0; i < buyOrderBook.length - 1; i++) {
            assert(buyOrderBook[i].price <= buyOrderBook[i + 1].price, "incorrect order in buy order book");
        }
    });

    it("SELL order book should be sorted in decreasing manner", async() => {
        await link.approve(dex.address, 3);
        await dex.deposit(3, linkTicker);

        await dex.createLimitOrder(1, linkTicker, 1, 300);
        await dex.createLimitOrder(1, linkTicker, 1, 100);
        await dex.createLimitOrder(1, linkTicker, 1, 200);

        let sellOrderBook = await dex.getOrderBook(linkTicker, 1);
        assert(sellOrderBook.length > 0, "incorrect size of sell order book");
        for (let i = 0; i < sellOrderBook.length - 1; i++) {
            assert(sellOrderBook[i].price >= sellOrderBook[i + 1].price, "incorrect order in sell order book");
        }
    });

})