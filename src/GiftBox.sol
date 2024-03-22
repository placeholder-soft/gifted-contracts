// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/access/AccessControl.sol";
import "@openzeppelin/token/ERC721/extensions/ERC721Burnable.sol";
import "./GiftedAccount.sol";

/// @custom:security-contact zitao@placeholdersoft.com
contract GiftBox is ERC721, ERC721Pausable, AccessControl, ERC721Burnable {
    /// defines
    struct TransferRecord {
        uint256 transferAt;
        address from;
        address to;
    }

    event ClawbackTimeUpdated(uint256 clawbackThreshold);
    event Clawback(address indexed from, address indexed to, uint256 tokenId);
    event GiftSent(address indexed from, address indexed to, uint256 tokenId);

    /// storage

    uint256 private _nextTokenId;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public __baseURI;
    string public _contractMetadataURI;

    mapping(uint256 => TransferRecord) public _lastGiftedRecords;

    uint256 public _clawbackThreshold = 30 days;
    uint256 immutable _minimalClawbackTime = 0 days;
    uint256 immutable _maximalClawbackTime = 30 days;

    constructor() ERC721("GiftBox", "GT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function grantRole(bytes32 role, address account) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function _baseURI() internal view override returns (string memory) {
        return __baseURI;
    }

    function setBaseURI(string memory baseURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        __baseURI = baseURI;
    }

    function setContractURI(string memory contractMetadataURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _contractMetadataURI = contractMetadataURI;
    }

    function contractURI() public view returns (string memory) {
        return _contractMetadataURI;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    function safeMintTransferGift(address mintTo, address transferTo) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(mintTo, tokenId);
        safeTransferGift(mintTo, transferTo, tokenId);
    }

    function nextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Pausable)
        returns (address from)
    {
        from = super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// clawback
    function updateClawbackThreshold(uint256 clawbackThreshold) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            clawbackThreshold >= _minimalClawbackTime,
            "clawbackThreshold must be greater than or equal to _minimalClawbackTime"
        );
        require(
            clawbackThreshold <= _maximalClawbackTime,
            "clawbackThreshold must be less than or equal to _maximalClawbackTime"
        );
        _clawbackThreshold = clawbackThreshold;
        emit ClawbackTimeUpdated(clawbackThreshold);
    }

    function safeTransferGiftFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId);
        _lastGiftedRecords[tokenId] = TransferRecord(block.timestamp, from, to);
        emit GiftSent(from, to, tokenId);
    }

    function safeTransferGift(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId);
        _lastGiftedRecords[tokenId] = TransferRecord(block.timestamp, from, to);
        emit GiftSent(from, to, tokenId);
    }

    function clawback(uint256 tokenId) public {
        require(_ownerOf(tokenId) != address(0), "token does not exist");
        require(_lastGiftedRecords[tokenId].from != address(0), "from address is zero address");
        require(_lastGiftedRecords[tokenId].to != address(0), "to address is zero address");
        require(_lastGiftedRecords[tokenId].from != _lastGiftedRecords[tokenId].to, "from and to address are the same");
        require(msg.sender == _lastGiftedRecords[tokenId].from, "sender is not the from address");
        require(block.timestamp - _lastGiftedRecords[tokenId].transferAt <= _clawbackThreshold, "clawback time expired");

        address to = _lastGiftedRecords[tokenId].to;

        _safeTransfer(to, _lastGiftedRecords[tokenId].from, tokenId, "");

        // invalidate the lastGiftedRecord
        delete _lastGiftedRecords[tokenId];

        emit Clawback(msg.sender, to, tokenId);
    }

    function clawback(uint256 tokenId, address to) public {
        require(_lastGiftedRecords[tokenId].to != to, "to address is the same as the last transfer to address");
        clawback(tokenId);
        safeTransferGiftFrom(msg.sender, to, tokenId);
    }
}
