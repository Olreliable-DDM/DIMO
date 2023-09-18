//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

// Import the NftBaseUpgradeable contract
import "https://raw.githubusercontent.com/DIMO-Network/dimo-identity/ef04762ea531d1d2adc8670d8fa28d1eff408db0/contracts/NFTs/Base/NftBaseUpgradeable.sol";

/// @title PartnershipNFT
/// @notice NFT Contract for representing Partnerships with specific requirements.
contract PartnershipNFT is NftBaseUpgradeable {

    // Custom events
    event CustomTransferRestriction(bool isRestricted);

    // State variables for custom features
    bool public customTransferRestriction;

    /// @notice Initialize PartnershipNFT contract
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param baseUri Token base URI
    function initialize(string calldata name, string calldata symbol, string calldata baseUri) public initializer {
        _baseNftInit(name, symbol, baseUri);
    }

    /// @notice Enforces transfer restrictions
    /// @dev Override the basic transfer functions to enforce custom rules
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param tokenId The NFT to transfer
    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        if (customTransferRestriction) {
            require(hasRole(TRANSFERER_ROLE, msg.sender), "PartnershipNFT: Caller does not have transferer role");
        }
        super._transfer(from, to, tokenId);
    }

    /// @notice Sets whether or not custom transfer restrictions should apply
    /// @dev Can only be set by admin
    /// @param _isRestricted Boolean indicating restriction status
    function setCustomTransferRestriction(bool _isRestricted) external onlyRole(ADMIN_ROLE) {
        customTransferRestriction = _isRestricted;
        emit CustomTransferRestriction(_isRestricted);
    }
}
