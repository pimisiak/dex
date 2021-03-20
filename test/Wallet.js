const Wallet = artifacts.require("Dex");
const Link = artifacts.require("Link");

const truffleAssert = require('truffle-assertions');

contract("Wallet", accounts => {
    let wallet;
    let link;

    before(async() => {
        wallet = await Wallet.deployed();
        link = await Link.deployed();
    })

    it("should only be possible for owner to add tokens", async() => {
        await truffleAssert.passes(
            wallet.addToken(web3.utils.fromUtf8("LINK"), link.address, {from: accounts[0]})
        );
        await truffleAssert.reverts(
            wallet.addToken(web3.utils.fromUtf8("LINK"), link.address, {from: accounts[1]})
        );
    })

    it("should handle faulty deposits correctly", async() => {
        await truffleAssert.reverts(
            wallet.deposit(100, web3.utils.fromUtf8("LINK"))
        );
    })

    it("should handle deposits correctly", async() => {
        await link.approve(wallet.address, 500);
        await wallet.deposit(100, web3.utils.fromUtf8("LINK"));
        let balance = await wallet.balances(accounts[0], web3.utils.fromUtf8("LINK"));
        assert.equal(balance.toNumber(), 100);
    })

    it("should handle faulty withdrawals correctly", async() => {
        await truffleAssert.reverts(
            wallet.withdraw(200, web3.utils.fromUtf8("LINK"))
        );
    })

    it("should handle withdrawals correctly", async() => {
        await truffleAssert.passes(
            wallet.withdraw(100, web3.utils.fromUtf8("LINK"))
        );
    })

})