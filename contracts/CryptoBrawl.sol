pragma solidity ^0.5.0;

contract SignatureVerification {

    function recover(bytes32 hash, bytes memory signature)
    internal
    pure
    returns (address)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        if (signature.length != 65) {
            return (address(0));
        }

        // Divide the signature in r, s and v variables with inline assembly.
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
        if (v < 27) {
            v += 27;
        }

        // If the version is correct return the signer address
        if (v != 27 && v != 28) {
            return (address(0));
        } else {
            // solium-disable-next-line arg-overflow
            return ecrecover(hash, v, r, s);
        }
    }

    /**
      * toEthSignedMessageHash
      * @dev prefix a bytes32 value with "\x19Ethereum Signed Message:"
      * and hash the result
      */
    function toEthSignedMessageHash(bytes32 hash)
    internal
    pure
    returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
    }
}


contract CryptoBrawl is SignatureVerification {


    struct Character {
        uint8 level;
        uint256 fightsCount;
        uint256 winsCount;
        uint8 fullHp;
        uint8 damage;
        uint256 fightId;
        uint8 currentHP;
        uint256 lastFihgtBlockNumber;
    }

    struct Fight {
        bytes32 player1CharID;
        bytes32 player2CharID;
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
    mapping (uint8 => bytes32) public challengesList; // level => charID
    mapping (address => address) public temporaryAddresses; // genaral => temp
    mapping (bytes32 => address) private charsTopPlayer; // charID => main acc
    mapping (address => bytes32) private playerToChars;
    uint256 private _challengeCount;
    uint256 public _fightsCount;

    Character private defaultChar = Character(
        1, // defaultLevel
        0, // fightsCount
        0, // winsCount
        45, // default fullHP
        15, // default damage
        0, // fightId
        45,
        0
    );

    event LookingForAFight(address player, uint256 level);
    event FightCreated(address player1, address player2, uint256 fightId);
    event FightFinished(address winner, uint256 fightId);



    function createFight(uint8 level, bytes32 player2CharID) internal {
        bytes32 player1CharID = challengesList[level];
        challengesList[level] = 0;
        _fightsCount += 1;
        Fight memory _newFight = Fight(
            player1CharID, //player1Character
            player2CharID, // player2Character
            charsTopPlayer[player1CharID], // player1GeneralAddress
            msg.sender, // player2GeneralAddress
            temporaryAddresses[charsTopPlayer[player1CharID]], // player1TempAddress
            temporaryAddresses[msg.sender], // player2TempAddress
            1, // current step
            block.number, //  current blockNumber
            address(0));  // address winner
        fights[_fightsCount] = _newFight;
        chars[player1CharID].fightId = _fightsCount;
        chars[player2CharID].fightId = _fightsCount;
        emit FightCreated(charsTopPlayer[player1CharID],msg.sender, _fightsCount);
    }

    function searchFight(address ERC721, uint256 tokenID, address tempAddress) public  {
        // проверка валидатора
        require(temporaryAddresses[msg.sender] == address(0), "already have a challenge");
        bytes32 _charID = genCharId(ERC721, tokenID); // generate charID
        require(chars[_charID].fightId == 0); // check if char in fight
        require(challengesList[chars[_charID].level] != _charID); // check if char in challenge
        if (chars[_charID].level == 0) {
            chars[_charID] = defaultChar;
        }
        charsTopPlayer[_charID] = msg.sender; //
        playerToChars [msg.sender] = _charID;
        chars[_charID].currentHP = chars[_charID].fullHp;
        uint8 level = chars[_charID].level;
        temporaryAddresses[msg.sender] = tempAddress;
        if (challengesList[level] == 0) {
            challengesList[level] = _charID;
            emit LookingForAFight(msg.sender, level);
        }
        else {
            createFight(level,_charID);
        }
    }

    function checkAction(
        uint256 fightID,
        uint256 stepNum,
        uint256 playerAction1,
        uint256 playerAction2,
        string memory playerSalt,
        bytes memory signature) public pure returns(address)
    {
        bytes32 hash = keccak256(abi.encodePacked(fightID,
            stepNum,
            playerAction1,
            playerAction2,
            playerSalt));
        bytes32 messageHash = toEthSignedMessageHash(hash);
        address signer = recover(messageHash, signature);
        return signer;
    }

    function calculateDamage(
        uint256 playerAction1,
        uint256 playerAction2,
        uint256 oponentAction1,
        uint256 oponentAction2 ) public pure returns(uint8)
    {
        uint8 damageDealed;
        if (playerAction1 == 1 || playerAction2 == 1) {
            if (oponentAction1 != 4 && oponentAction2 != 4)  {
                damageDealed +=1;
            }
        }
        if (playerAction1 == 2|| playerAction2 == 2) {
            if (oponentAction1 != 5 && oponentAction2 != 5)  {
                damageDealed +=1;
            }
        }
        if (playerAction1 == 3|| playerAction2 == 3) {
            if (oponentAction1 != 6 && oponentAction2 != 6)  {
                damageDealed +=1;
            }
        }
        return damageDealed;
    }


    function actionSet(
        uint256 fightID,
        uint256 stepNum,
        uint256 player1Action1,
        uint256 player1Action2,
        uint256 player2Action1,
        uint256 player2Action2,
        string memory player1Salt,
        string memory player2Salt,
        bytes memory player1Signature,
        bytes memory player2Signature
    ) public
    {
        require(fightID == chars[playerToChars[msg.sender]].fightId);
        require(player1Action1 != player1Action2 && player2Action1 != player2Action2, "unavailable actions");
        Fight memory currentFight = fights[fightID];
        require(checkAction(
            fightID,
            stepNum,
            player1Action1,
            player1Action2,
            player1Salt,player1Signature) == currentFight.player1TempAddress
        &&
        checkAction(
            fightID,
            stepNum,
            player2Action1,
            player2Action2,
            player2Salt,player2Signature) == currentFight.player2TempAddress
        );  // validate that actions actualy signed by current players
        //require(stepNum == currentFight.stepNum)
        /**
        if (stepNum%2 == 0)
        {
            require(msg.sender == currentFight.player2GeneralAddress);
        }
        else
        {
            require(msg.sender == currentFight.player1GeneralAddress);
        }
        */
        //calculate damage by player2
        uint8 player1Damage = calculateDamage(player1Action1,player1Action2, player2Action1, player2Action2) * (chars[currentFight.player1CharID].damage);
        //calculate damage by player2
        uint8 player2Damage = calculateDamage(player2Action1,player2Action2, player1Action1, player1Action2) * (chars[currentFight.player2CharID].damage);

        fights[fightID].lastStepBlock = block.number;
        fights[fightID].stepNum +=1;

        if (chars[currentFight.player1CharID].currentHP <= player2Damage
            || chars[currentFight.player2CharID].currentHP <= player1Damage) {

            if (chars[currentFight.player1CharID].currentHP <= player2Damage) {

                chars[currentFight.player1CharID].currentHP = chars[currentFight.player1CharID].fullHp;
                chars[currentFight.player2CharID].currentHP = chars[currentFight.player2CharID].fullHp;
                fights[fightID].winner = currentFight.player2GeneralAddress;
                chars[currentFight.player2CharID].winsCount +=1;
                emit FightFinished(fights[fightID].winner,fightID);

            }
            else {
                chars[currentFight.player1CharID].currentHP = chars[currentFight.player1CharID].fullHp;
                chars[currentFight.player2CharID].currentHP = chars[currentFight.player2CharID].fullHp;
                fights[fightID].winner = currentFight.player1GeneralAddress;
                chars[currentFight.player1CharID].winsCount +=1;
                emit FightFinished(fights[fightID].winner,fightID);
                // player2Char.level +=1;
            }
            chars[currentFight.player1CharID].fightsCount +=1;
            chars[currentFight.player2CharID].fightsCount +=1;
            chars[currentFight.player1CharID].lastFihgtBlockNumber = block.number;
            chars[currentFight.player2CharID].lastFihgtBlockNumber = block.number;
            chars[currentFight.player1CharID].fightId = 0;
            chars[currentFight.player2CharID].fightId = 0;
            temporaryAddresses[currentFight.player1GeneralAddress] = address (0);
            temporaryAddresses[currentFight.player2GeneralAddress] = address (0);
        }
        else {
            chars[currentFight.player1CharID].currentHP -= player2Damage;
            chars[currentFight.player2CharID].currentHP -= player1Damage;
        }

    }


    function genCharId(address ERC721, uint256 tokenID) public pure returns(bytes32){
        bytes32 _charID = keccak256(abi.encodePacked(ERC721, tokenID));
        return _charID;
    }



    /**

    function cancelSearch(address ) public {

    }

    function giveUp() public {

    }

    /**
    function claimTimeOut(uint256 fightID) public {
        if (fights[fightID].stepNum % 2 == 0) {
            if (fights[fightID].player1GeneralAddress == msg.sender) {

            }
        }

    }
    */

}