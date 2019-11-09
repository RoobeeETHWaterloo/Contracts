const CryptoBrawl = artifacts.require("CryptoBrawl");
const Web3 = require('web3');
const provider = new Web3.providers.HttpProvider('http://sip1.skalenodes.com:10046');
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

    it("start fight and create another char", async  () => {
        let brawl = await CryptoBrawl.deployed();
        await brawl.searchFight(address721, tokenID2, tempaddress2,{from:accounts[2]});
        let char = await brawl.chars.call(web3.utils.soliditySha3(address721, tokenID2));
        let activeSearch = await brawl.challengesList.call(1);
        assert.equal(activeSearch, 0);
        let player1FightId = await brawl.chars.call(web3.utils.soliditySha3(address721, tokenID1));
        player1FightId = player1FightId.fightId.toNumber();
        let player2FightId = await brawl.chars.call(web3.utils.soliditySha3(address721, tokenID2));
        player2FightId = player2FightId.fightId.toNumber();
        let fight = await brawl.fights.call(1);
    });

    it("should set first action" , async () => {
        let brawl = await CryptoBrawl.deployed();
        let char = await brawl.chars.call(web3.utils.soliditySha3(address721, tokenID1));
        let fightID = char.fightId.toNumber();
        console.log(fightID);
        let fight = await brawl.fights.call(fightID);
        console.log(fight);
        let stepNum = fight.stepNum.toNumber();
        console.log(stepNum);
        var hash1 = web3.utils.soliditySha3(fightID, stepNum, 1, 2, "aaa");
        var hash2 = web3.utils.soliditySha3(fightID, stepNum, 1, 6, "bbb");
        var signature1 = await web3.eth.sign(hash1, tempaddress1);
        console.log(signature1);
        var signature2 = await web3.eth.sign(hash2, tempaddress2);
        console.log(signature2);
        let check1 = await brawl.checkAction.call(fightID,stepNum, 1, 2, "aaa", signature1);
        let check2 = await brawl.checkAction.call(fightID,stepNum, 1, 6, "bbb", signature2);
        console.log(check1);
        console.log(check2);
        await brawl.actionSet(fightID, stepNum, 1, 2, 1, 6, "aaa", "bbb", signature1, signature2)

    });
});




constructor (uint8 level,
    uint256 fightsCount,
    uint256 winsCount,
    uint8 fullHp,
    uint8 damage,
    uint256 fightId,
    uint8 currentHP,
    uint256 lastFihgtBlockNumber)
public {
    defaultChar = Character(level, fightsCount, winsCount, fullHp, damage, fightId,currentHP,lastFihgtBlockNumber);

}
