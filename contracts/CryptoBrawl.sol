pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

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

    using SafeMath for uint;

    struct Character {
        uint256 level;
        uint256 fightsCount;
        uint256 winsCount;
        uint256 fullHp;
        uint256 damage;
        string avatarUrl;
        string info;
        //uint256 activeChallengeID;
        uint256 fightId;
        uint256 currentHP;
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
    mapping (uint256 => bytes32) public challengesList; // level => charID
    mapping (address => address) private temporaryAddresses; // genaral => temp
    mapping (bytes32 => address) public charsTopPlayer; // charID => main acc
    uint256 private _challengeCount;
    uint256 private _fightsCount;

    //Character private defaultChar = Character();

    event LookingForAFight(address player);
    event FightFinished(address winner);

    function createCharacter() internal {

    }

    function createFight(uint256 level, bytes32 playerCharID) internal {
        bytes32 _oponentsCharID = challengesList[level];
        address _oponentsAddress = temporaryAddresses[msg.sender];
        challengesList[level] = 0;
        _fightsCount += 1;
        Fight memory _newFight = Fight(playerCharID, //player1Character
            _oponentsCharID, // player2Character
            msg.sender, // player1
            charsTopPlayer[_oponentsCharID], // player2
            _oponentsAddress, // player1TempAddress
            temporaryAddresses[_oponentsAddress], // player2TempAddress
            1, // current step
            block.number, //  current blockNumber
            address(0));  // address winner
        fights[_fightsCount] = _newFight;
        chars[_oponentsCharID].fightId = _fightsCount;
        chars[playerCharID].fightId = _fightsCount;
    }

    function searchFight(address ERC721, uint256 tokenID, address tempAddress) public  {
        // проверка валидатора
        bytes32 _charID = keccak256(abi.encodePacked(ERC721, tokenID)); // generate charID
        require(chars[_charID].fightId == 0);
        if (chars[_charID].level == 0) {
            //chars[_charID] =
        }
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

    function checkAction(
        uint256 fightID,
        uint256 stepNum,
        uint256 playerAction1,
        uint256 playerAction2,
        string memory playerSalt,
        bytes memory signature) public view returns(address)
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
        uint256 oponentAction2 ) public pure returns(uint256)
    {
        uint256 damageDealed;
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
        require(player1Action1 != player1Action2 && player2Action1 != player2Action2, "unavailable actions");
        Fight memory currentFight = fights[fightID];
        address player1GeneralAddress = currentFight.player1GeneralAddress;
        address player2GeneralAddress = currentFight.player2GeneralAddress;
        require(checkAction(
            fightID,
            stepNum,
            player1Action1,
            player1Action2,
            player1Salt,player1Signature) == player1GeneralAddress
        &&
        checkAction(
            fightID,
            stepNum,
            player2Action1,
            player2Action2,
            player2Salt,player2Signature) == player2GeneralAddress
        );  // validate that actions actualy signed by current players
        bytes32 player1CharID = currentFight.player1CharID;
        bytes32 player2CharID = currentFight.player2CharID;
        Character memory player1Char = chars[player1CharID];
        Character memory player2Char = chars[player2CharID];
        uint256 player1DamageDealed = calculateDamage(player1Action1,player1Action2, player2Action1, player2Action2).mul(player1Char.damage);
        uint256 player2DamageDealed = calculateDamage(player2Action1,player2Action2, player1Action1, player1Action2).mul(player2Char.damage);
        player1Char.currentHP.sub(player2DamageDealed);
        player2Char.currentHP.sub(player1DamageDealed);
        fights[fightID].lastStepBlock = block.number;
        fights[fightID].stepNum +=1;
        if (player1Char.currentHP <= 0 || player2Char.currentHP <= 0) {
            player1Char.fightsCount +=1;
            player2Char.fightsCount +=1;
            if (player1Char.currentHP <= 0) {
                fights[fightID].winner == player2GeneralAddress;
                player2Char.winsCount +=1;
                // player2Char.level +=1;
            }
            else {
                fights[fightID].winner == player1GeneralAddress;
                player1Char.winsCount +=1;
                // player2Char.level +=1;
            }

            player1Char.lastFihgtBlockNumber = block.number;
            player2Char.lastFihgtBlockNumber = block.number;
            player1Char.fightId = 0;
            player2Char.fightId = 0;
        }


        chars[player1CharID] = player1Char;
        chars[player2CharID] = player2Char;
        // Посчитать и изменить хп игроков, номер хода
        // Если у кого то хп становится меньше либо равно нулю то удаляем бой, выставляем хп на некий уровень
        // EVENT
        // Повышаем левел, кол-во побед и тд.
        //
    }
}

