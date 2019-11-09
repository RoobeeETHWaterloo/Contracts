pragma solidity ^0.5.0;

contract CryptoBrawl {

    struct Character {
        uint256 level;
        uint256 fightsCount;
        uint256 winsCount;
        uint256 fullHp;
        uint256 strenght;
        string avatarUrl;
        string info;
        uint256 activeChallengeID;
        uint256 fightId;
        uint256 currentHP;
        uint256 lastFihgtBlockNumber;
    }

    struct Fight {
        bytes32 player1Char;
        bytes32 player2Char;
        address player1GeneralAddress;
        address player2GeneralAddress;
        address player1TempAddress;
        address player2TempAddress;
        uint256 stepNum;
        uint256 lastStepBlock;
        address winner; // победитель боя, либо 0x00 если бой в процессе
    }

    mapping (bytes32 => Character) public chars;
    mapping (uint256 => Fight) public fights;
    mapping (uint256 => bytes32) public challengesList; // level => charID
    mapping (address => address) private temporaryAddresses; // genaral => temp
    mapping (bytes32 => address) public charsTopPlayer; // charID => main acc
    uint256 private _challengeCount;
    uint256 private _fightsCount;

    event LookingForAFight(address);

    function createCharacter() internal {

    }

    function createFight(uint256 level, bytes32 charID) internal {
        bytes32 _oponentsCharID = challengesList[level];
        address _oponentsAddress = temporaryAddresses[msg.sender];
        challengesList[level] = 0;
        _fightsCount += 1;
        Fight memory _newFight = Fight(charID, //player1Character
            _oponentsCharID, // player2Character
            msg.sender, // player1
            charsTopPlayer[_oponentsCharID], // player2
            _oponentsAddress, // player1TempAddress
            temporaryAddresses[_oponentsAddress], // player2TempAddress
            1, // current step
            block.number, //  current blockNumber
            address(0));  // address winner
        fights[_fightsCount] = _newFight;
    }

    function searchFight(address ERC721, uint256 tokenID, address tempAddress) public  {
        // проверка валидатора
        bytes32 _charID = keccak256(abi.encodePacked(ERC721, tokenID)); // generate charID
        charsTopPlayer[_charID] = msg.sender; //
        uint256 level = chars[_charID].level;
        temporaryAddresses[msg.sender] = tempAddress;
        if (challengesList[level] == 0) {
            challengesList[level] = _charID;
        }
        else {
            createFight(level,_charID);
        }
    }

    function actionSet(
        uint256 fightID,
        uint256 stepNum,
        uint256 player1Action1,
        uint256 player1Action2,
        uint256 player2Action1,
        uint256 player2Action2,
        bytes32 player1Salt,
        bytes32 player2Salt,
        bytes32 player1Signature,
        bytes32 player2Signature
    ) public
    {
        Fight memory currentFight = fights[fightID];

        // Проверить что подписи принадлежать player1 и player2
        // Посчитать и изменить хп игроков, номер хода
        // Если у кого то хп становится меньше либо равно нулю то удаляем бой, выставляем хп на некий уровень
        // EVENT
        // Повышаем левел, кол-во побед и тд.
        //
    }




}