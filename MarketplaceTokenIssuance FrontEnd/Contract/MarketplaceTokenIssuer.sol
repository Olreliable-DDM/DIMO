// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title MarketplaceTokenIssuer
 * @dev This smart contract allows authorized entities (represented as NFTs) to issue ERC20 tokens to users.
 * This version of the contract is upgradable. To upgrade, follow the upgrade guide.
 */
contract MarketplaceTokenIssuer is Initializable, AccessControl {
    // Define roles for role-based access control
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    
    // ERC20 token and NFT interfaces
    IERC20 private _token; 
    IERC721 public partnerNFT;

    // The master wallet that is allowed to issue tokens
    address public masterWallet;

    // Cooldown period between issuance (in seconds)
    uint256 public constant COOLDOWN_PERIOD = 28 days;

    // Mapping to keep track of the last issuance date for each user-token pair
    mapping(address => mapping(uint256 => uint256)) public lastIssuanceDate;

    /// @notice Emitted when tokens are successfully issued
    event TokensIssued(address indexed user, uint256 indexed tokenId, uint256 amount);
    
    /// @notice Emitted when a partner NFT address is set
    event PartnerNFTSet(address partnerNFTAddress);
    
    /// @dev Initializes the contract setting the token and masterWallet addresses
    /// @param tokenAddress The address of the ERC20 token
    /// @param _masterWallet The address allowed to issue tokens
    function initialize(address tokenAddress, address _masterWallet) public initializer {
        _token = IERC20(tokenAddress);
        masterWallet = _masterWallet;
        
        // Setup default roles
        _setupRole(OWNER_ROLE, _msgSender());
    }

    /**
     * @dev Checks if the cooldown has passed for a specific user-token pair.
     * @param user The user's address.
     * @param tokenId The NFT token ID.
     * @return True if the cooldown has passed, false otherwise.
     */
    function isCooldownPassed(address user, uint256 tokenId) public view returns (bool) {
        return block.timestamp >= lastIssuanceDate[user][tokenId] + COOLDOWN_PERIOD;
    }

    /**
     * @dev Sets the partner NFT address.
     * @param nftAddress The address of the partner NFT.
     */
    function setPartnerNFT(address nftAddress) external {
        require(hasRole(OWNER_ROLE, _msgSender()), "Caller is not the owner");
        partnerNFT = IERC721(nftAddress);
        emit PartnerNFTSet(nftAddress);
    }

    /**
    * @dev Returns the number of tokens available in the contract.
    * @return The number of tokens available.
    */
    function availableTokens() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }


    /**
     * @dev Issue tokens to multiple users.
     * @param users Array of user addresses.
     * @param tokenIds Array of NFT token IDs.
     * @param amounts Array of token amounts.
     */
    function issueTokensToMultipleUsers(
        address[] memory users, 
        uint256[] memory tokenIds, 
        uint256[] memory amounts
    ) external {
        require(hasRole(OWNER_ROLE, _msgSender()), "Caller is not the owner");
        require(users.length == tokenIds.length && users.length == amounts.length, "Array lengths mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            require(isCooldownPassed(users[i], tokenIds[i]), "Cooldown period not passed for user-token pair");
            require(_token.transfer(users[i], amounts[i]), "Token transfer failed");
            lastIssuanceDate[users[i]][tokenIds[i]] = block.timestamp;
            emit TokensIssued(users[i], tokenIds[i], amounts[i]);
        }
    }
}
