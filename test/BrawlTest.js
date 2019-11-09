const CryptoBrawl = artifacts.require("CryptoBrawl");
const Web3 = require('web3');
const provider = new Web3.providers.HttpProvider('http://localhost:7545');
const web3 = new Web3(provider);
const truffleAssert = require('truffle-assertions');

const address721 = "0x06012c8cf97bead5deae237070f9587f8e7a266d";
const tokenID1 = 1256264;
const tokenID2 = 1256265;
const tempaddress1 = "0x07E691eceaFD6F6571BA296C69A775C186C274b7";
const tempaddress2 = "0xa085aeC2c42D3f68C1c1484661EBa58514cbDD2E";



contract("CryptoBrawlTest", async accounts => {

    it("should start new Search and create char", async () => {
        let brawl = await CryptoBrawl.deployed();
        await brawl.searchFight(address721, tokenID1, tempaddress1);
        let char = await brawl.chars.call(web3.utils.soliditySha3(address721, tokenID1));
        let activeSearch = await brawl.challengesList.call(1);
        assert.equal(activeSearch, web3.utils.soliditySha3(address721, tokenID1))
    });

    it(" start fight and create another char", async  () => {
        let brawl = await CryptoBrawl.deployed();
        await brawl.searchFight(address721, tokenID2, tempaddress2);
        let char = await brawl.chars.call(web3.utils.soliditySha3(address721, tokenID2));
        let activeSearch = await brawl.challengesList.call(1);
        assert.equal(activeSearch, 0);
        let player1FightId = await brawl.chars.call(web3.utils.soliditySha3(address721, tokenID1));
        player1FightId = player1FightId.fightId.toNumber();
        let player2FightId = await brawl.chars.call(web3.utils.soliditySha3(address721, tokenID2));
        player2FightId = player2FightId.fightId.toNumber();
        let player1Fight = await brawl.fights.call(player1FightId);
        let player2Fight = await brawl.fights.call(player2FightId);
        let fight = await brawl.fights.call(1);
    });

    it()
});