pragma solidity 0.8.3;

import "OpenZeppelin/openzeppelin-contracts@4.2.0/contracts/access/Ownable.sol";
import "OpenZeppelin/openzeppelin-contracts@4.2.0/contracts/security/ReentrancyGuard.sol";
import "OpenZeppelin/openzeppelin-contracts@4.2.0/contracts/utils/math/SafeMath.sol";
import "OpenZeppelin/openzeppelin-contracts@4.2.0/contracts/token/ERC721/IERC721.sol";
import "OpenZeppelin/openzeppelin-contracts@4.2.0/contracts/token/ERC721/IERC721Receiver.sol";


/**  This provides a basic template for teams based on FootyVerse players. */

contract Team is ReentrancyGuard, Ownable, IERC721Receiver {

    using SafeMath for uint256;
    
    address public immutable footyToken;
    uint256 public immutable leasePeriodInBlocks;
    uint256 public immutable leaseValue;

    struct Player {
        uint256 tokenId;
        uint256 leaseStartBlockNumber; 
    }

    Player[] public players;
    mapping(uint256 => bool) public submittedPlayers;
    mapping(uint256 => address) public submittedPlayersOwner;
    
    constructor(address _owner, address _footyToken, uint256 _leasePeriodInBlocks, uint256 _leaseValue) Ownable() {
        footyToken = _footyToken;
        leasePeriodInBlocks = _leasePeriodInBlocks;
        leaseValue = _leaseValue;
        transferOwnership(_owner);
    }

    function isPlayer(uint256 tokenId) public view returns (bool) {
        for (uint256 i = 0; i<11; i++) {
            if (players[i].tokenId == tokenId) {
                return true;
            }
        }
        return false;
    }

    function isActiveTeam() external view returns (bool) {
        if (players.length == 11) {
            for (uint256 i = 0; i<11; i++) { 
                if (players[i].leaseStartBlockNumber.add(leasePeriodInBlocks) > block.number) {
                    return false;
                }
            }
            return true;
        } else {
            return false;
        }
    }

    function submitPlayer(uint256 tokenId) external nonReentrant {
        require(IERC721(footyToken).ownerOf(tokenId) == msg.sender, "Not the owner");
        IERC721(footyToken).safeTransferFrom(msg.sender, address(this), tokenId);   // TODO onERC721Received
        submittedPlayers[tokenId] = true;
        submittedPlayersOwner[tokenId] = msg.sender;
    }

    function addPlayerToTeam(uint256 tokenId) external nonReentrant onlyOwner {
        require(submittedPlayers[tokenId], "Not submitted");
        require(players.length < 11, "Team full");
        (bool success, ) = submittedPlayersOwner[tokenId].call{value:leaseValue}("");
        require(success, "Ether transfer failed");
        Player memory player;
        player.tokenId = tokenId;
        player.leaseStartBlockNumber = block.number;
        players.push(player);
    }

    function removePlayerFromTeam(uint256 tokenId) external nonReentrant onlyOwner {        
        for (uint256 i = 0; i < players.length; i++) {
            if (tokenId == players[i].tokenId) {
                if (i != players.length - 1) {
                    players[i] = players[players.length - 1];
                }
                players.pop();
                return;
            }
        }

        require(false, "Not in the team");
    }

    function takeBackPlayer(uint256 tokenId) external {
        require(submittedPlayers[tokenId], "Not submitted");
        require(submittedPlayersOwner[tokenId] == msg.sender, "Not your player");
        for (uint256 i = 0; i < players.length; i++) {
            if (tokenId == players[i].tokenId) {
                require (players[i].leaseStartBlockNumber.add(leasePeriodInBlocks) < block.number, "Lease period not over");
                if (i != players.length - 1) {
                    players[i] = players[players.length - 1];
                }
                players.pop();
            }
        }
        submittedPlayers[tokenId] = false;
        IERC721(footyToken).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function deposit() external payable onlyOwner {

    }
}
