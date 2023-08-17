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
    IERC20 private _token; // ERC20 token to be issued
    IERC721 public partnerNFT; // NFT representing authorized partners
    address public masterWallet; // Address where all the partner NFTs are stored

    uint256 public constant MIN_ISSUANCE_AMOUNT = 0;
    uint256 public constant COOLDOWN_PERIOD = 4 weeks; // Cooldown period for token issuance

    mapping(address => mapping(uint256 => uint256)) public lastIssuanceDate; // Last issuance dates for user-token pairs

    event TokensIssued(address indexed user, uint256 indexed tokenId, uint256 amount);
    event PartnerNFTSet(address partnerNFTAddress);
    event TokensDeposited(uint256 amount);

    constructor(address tokenAddress, address _masterWallet) {
        _token = IERC20(tokenAddress);
        masterWallet = _masterWallet;
    }

    modifier cooldownPassed(address user, uint256 tokenId) {
        require(block.timestamp >= lastIssuanceDate[user][tokenId] + COOLDOWN_PERIOD, "ERR01: Cooldown period not passed");
        _;
    }

    /**
     * @dev Sets the partner NFT address. Can only be called by the contract owner.
     * @param nftAddress - Address of the NFT representing partners.
     */
    function setPartnerNFT(address nftAddress) external onlyOwner {
        partnerNFT = IERC721(nftAddress);
        emit PartnerNFTSet(nftAddress);
    }

    /**
     * @dev Partners can issue tokens to multiple users.
     * @param users - Array of users to issue tokens to.
     * @param tokenIds - Array of tokenIds representing partners.
     * @param amounts - Array of token amounts to issue.
     */
    function issueTokensToMultipleUsers(
        address[] memory users,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    )
        external
        nonReentrant
    {
        require(users.length == tokenIds.length && users.length == amounts.length, "ERR02: Array lengths mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < users.length; i++) {
            require(amounts[i] >= MIN_ISSUANCE_AMOUNT, "ERR03: Amount below the minimum issuance threshold");
            require(partnerNFT.ownerOf(tokenIds[i]) == masterWallet, "ERR04: Not authorized for this partner NFT");
            cooldownPassed(users[i], tokenIds[i]); // Apply cooldown check for user-tokenId pair
            totalAmount += amounts[i];
        }

        require(_token.balanceOf(address(this)) >= totalAmount, "ERR05: Not enough token balance in the contract");

        for (uint256 i = 0; i < users.length; i++) {
            _token.transfer(users[i], amounts[i]);
            lastIssuanceDate[users[i]][tokenIds[i]] = block.timestamp;
            emit TokensIssued(users[i], tokenIds[i], amounts[i]);
        }
    }

    /**
     * @dev Allows the owner to deposit tokens to the contract.
     * @param amount - Amount of tokens to deposit.
     */
    function depositTokens(uint256 amount) external onlyOwner {
        require(_token.transferFrom(msg.sender, address(this), amount), "ERR06: Token transfer failed");
        emit TokensDeposited(amount);
    }

    /**
     * @dev Allows the owner to recover any ERC20 tokens sent to the contract by mistake.
     * @param tokenAddress - Address of the ERC20 token to recover.
     * @param recipient - Address where the recovered tokens will be sent.
     * @param amount - Amount of tokens to recover.
     */
    function recoverERC20(address tokenAddress, address recipient, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(recipient, amount);
    }
}
