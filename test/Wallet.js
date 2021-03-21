const Wallet = artifacts.require("Dex");
const Link = artifacts.require("Link");

const truffleAssert = require('truffle-assertions');

contract("Wallet", accounts => {
    let wallet;
    let link;
    let linkTicker;

    before(async() => {
        wallet = await Wallet.deployed();
        link = await Link.deployed();
        linkTicker = web3.utils.fromUtf8("LINK");
    })

    it("should only be possible for owner to add tokens", async() => {
        await truffleAssert.passes(
            wallet.addToken(linkTicker, link.address, {from: accounts[0]})
        );
        await truffleAssert.reverts(
            wallet.addToken(linkTicker, link.address, {from: accounts[1]})
        );
    })

    it("should handle faulty token deposits correctly", async() => {
        await truffleAssert.reverts(
            wallet.deposit(100, linkTicker)
        );
    })

    it("should handle token deposits correctly", async() => {
        await link.approve(wallet.address, 500);
        await wallet.deposit(100, linkTicker);
        let balance = await wallet.balances(accounts[0], linkTicker);
        assert.equal(balance.toNumber(), 100);
    })

    it("should handle faulty token withdrawals correctly", async() => {
        await truffleAssert.reverts(
            wallet.withdraw(200, linkTicker)
        );
    })

    it("should handle token withdrawals correctly", async() => {
        await truffleAssert.passes(
            wallet.withdraw(100, linkTicker)
        );
    })

    it("should handle eth deposits correctly", async() => {
        await truffleAssert.passes(
            wallet.depositEth({value: 100})
        );
    })

    it("should handle eth faulty withdrawals correctly", async() => {
        await truffleAssert.reverts(
            wallet.withdrawEth(200)
        );
    })

    it("should handle eth withdrawals correctly", async() => {
        await truffleAssert.passes(
            wallet.withdrawEth(100)
        );
    })

})