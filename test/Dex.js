const Dex = artifacts.require("Dex");
const Link = artifacts.require("Link");

const truffleAssert = require('truffle-assertions');

contract("Dex", accounts => {
    let dex;
    let link;

    before(async() => {
        dex = await Dex.deployed();
        link = await Link.deployed();
    })
    
})