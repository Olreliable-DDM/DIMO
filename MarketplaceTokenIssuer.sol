// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title MarketplaceTokenIssuer
 * @dev This smart contract enables authorized partners (represented as NFTs) to issue tokens to users. 
 */
contract MarketplaceTokenIssuer is ReentrancyGuard {
    IERC20 private _token; // The token that will be issued.
    IERC721 public partnerNFT;  // Represents our partners. Each unique tokenId is a different partner.

    uint256 public constant MIN_ISSUANCE_AMOUNT = 0; //1e18  // Minimum number of tokens a partner can issue in a single transaction.
    uint256 public constant COOLDOWN_PERIOD = 1 weeks;  // We can issue tokens once every week per user.

    mapping(address => uint256) public lastIssuanceTimestamp;  // Tracks the last time a user was issued tokens.
    mapping(uint256 => string) public tokenIdToPartner;  // Relates an NFT tokenId to the partner's name.

    // Events for logging significant contract actions
    event TokensIssued(address indexed user, uint256 indexed tokenId, uint256 amount);
    event PartnerNFTSet(address partnerNFTAddress);
    event PartnerRegistered(uint256 indexed tokenId, string partnerName);

    constructor(address tokenAddress) {
        _token = IERC20(tokenAddress);
    }

    // This modifier ensures that a user can only be issued tokens once per week.
    modifier cooldownPassed(address user) {
        require(block.timestamp >= lastIssuanceTimestamp[user] + COOLDOWN_PERIOD, "ERR01: Cooldown period not passed");
        _;
    }

    // Allows the contract to accept Eth (for testig purposes)
    receive() external payable {} 

    // Sets the partner NFT address. This is a one-time operation for added security.
    function setPartnerNFT(address nftAddress) external {
        partnerNFT = IERC721(nftAddress);
        emit PartnerNFTSet(nftAddress);
    }

    // Partners call this function to associate their NFT tokenId with their name.
    function registerPartner(uint256 tokenId, string memory partnerName) external {
        require(partnerNFT.ownerOf(tokenId) == msg.sender, "ERR02: Not the NFT owner");
        tokenIdToPartner[tokenId] = partnerName;
        emit PartnerRegistered(tokenId, partnerName);
    }

    // The main functionality: partners use this to issue tokens to multiple users with a single transaction.
    function issueTokensToOneClick(
        address[] memory users, 
        uint256[] memory tokenIds, 
        uint256[] memory amounts
    ) 
        external 
        nonReentrant 
        cooldownPassed(msg.sender)
    {
        // Make sure our arrays are all the same length.
        require(users.length == tokenIds.length && users.length == amounts.length, "ERR04: Array lengths mismatch");
        
        uint256 totalAmount = 0;

        // Verify that the issuance is valid and sum up the total amount of tokens being issued.
        for (uint256 i = 0; i < users.length; i++) {
            require(amounts[i] >= MIN_ISSUANCE_AMOUNT, "ERR05: Amount below the minimum issuance threshold");
            require(bytes(tokenIdToPartner[tokenIds[i]]).length > 0, "ERR06: Not authorized for this partner NFT");
            totalAmount += amounts[i];
        }

        // Makes sure the contract has enough tokens to cover the issuance.
        require(_token.balanceOf(address(this)) >= totalAmount, "ERR07: Not enough token balance in the contract");

        // Actual issuance happens here.
        for (uint256 i = 0; i < users.length; i++) {
            _token.transfer(users[i], amounts[i]);
            lastIssuanceTimestamp[users[i]] = block.timestamp;
            emit TokensIssued(users[i], tokenIds[i], amounts[i]);
        }
    }
}
