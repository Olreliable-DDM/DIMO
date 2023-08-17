// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MarketplaceTokenIssuer
 * @dev This smart contract enables authorized partners (represented as NFTs) to issue tokens to users. 
 */
contract MarketplaceTokenIssuer is ReentrancyGuard, Ownable {
    IERC20 private _token; 
    IERC721 public partnerNFT;
    address public masterWallet;

    uint256 public constant MIN_ISSUANCE_AMOUNT = 0;
    uint256 public constant COOLDOWN_PERIOD = 4 weeks; //

    mapping(address => mapping(uint256 => uint256)) public lastIssuanceDate;

    event TokensIssued(address indexed user, uint256 indexed tokenId, uint256 amount);
    event PartnerNFTSet(address partnerNFTAddress);
    event TokensDeposited(uint256 amount);

    constructor(address tokenAddress, address _masterWallet) {
        _token = IERC20(tokenAddress);
        masterWallet = _masterWallet;
    }

    /**
     * @dev Checks if the cooldown has passed for a specific user-token pair.
     * @param user - The user address.
     * @param tokenId - The tokenId.
     */
    function isCooldownPassed(address user, uint256 tokenId) public view returns (bool) {
        return block.timestamp >= lastIssuanceDate[user][tokenId] + COOLDOWN_PERIOD;
    }

    function setPartnerNFT(address nftAddress) external onlyOwner {
        partnerNFT = IERC721(nftAddress);
        emit PartnerNFTSet(nftAddress);
    }

    function issueTokensToMultipleUsers(
        address[] memory users, 
        uint256[] memory tokenIds, 
        uint256[] memory amounts
    ) 
        external 
        nonReentrant
    {
        require(users.length == tokenIds.length && users.length == amounts.length, "ERR04: Array lengths mismatch");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < users.length; i++) {
            require(amounts[i] >= MIN_ISSUANCE_AMOUNT, "ERR05: Amount below the minimum issuance threshold");
            require(partnerNFT.ownerOf(tokenIds[i]) == masterWallet, "ERR06: Not authorized for this partner NFT");
            require(isCooldownPassed(users[i], tokenIds[i]), "ERR01: Cooldown period not passed for user-token pair");
            totalAmount += amounts[i];
        }

        require(_token.balanceOf(address(this)) >= totalAmount, "ERR07: Not enough token balance in the contract");

        for (uint256 i = 0; i < users.length; i++) {
            _token.transfer(users[i], amounts[i]);
            lastIssuanceDate[users[i]][tokenIds[i]] = block.timestamp;
            emit TokensIssued(users[i], tokenIds[i], amounts[i]);
        }
    }

    function depositTokens(uint256 amount) external onlyOwner {
        require(_token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        emit TokensDeposited(amount);
    }

    function recoverERC20(address tokenAddress, address recipient, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(recipient, amount);
    }
}
