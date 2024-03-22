// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/utils/Address.sol";
import "erc6551/ERC6551Registry.sol";
import "./GiftBox.sol";
import "./GiftedAccount.sol";
import "./GiftedAccountGuardian.sol";
import "./interfaces/IGasSponsorBook.sol";

/// @custom:security-contact zitao@placeholdersoft.com
contract GiftBoxAccountHelper is Pausable, AccessControl {
    using Address for address payable;
    using Address for address;

    GiftedAccount public _accountImpl;
    GiftBox public _giftBox;
    ERC6551Registry public _registry;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    GiftedAccountGuardian public _guardian;
    IGasSponsorBook public _gasSponsorBook;

    /// events

    event MintTransferNFT(
        address indexed sender,
        address indexed to,
        address indexed nft,
        uint256 transferTokenId,
        uint256 giftBoxTokenId,
        address transferTo
    );
    event TransferEtherToAccount(address indexed account, address indexed from, uint256 value);
    event SponsorEnabled(address indexed account, uint256 tokenId, uint256 ticket);
    event SponsorTicketAdded(address indexed account, uint256 ticket, uint256 value);
    event MintTransferERC1155(
        address indexed sender,
        address indexed to,
        address indexed nft,
        uint256 id,
        uint256 amount,
        uint256 giftBoxTokenId,
        address transferTo
    );

    constructor(GiftedAccount accountImpl, GiftBox giftNft, ERC6551Registry registry, GiftedAccountGuardian guardian) {
        _accountImpl = accountImpl;
        _giftBox = giftNft;
        _registry = registry;
        _guardian = guardian;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setNFT(GiftBox giftNft) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _giftBox = giftNft;
    }

    function setAccountImpl(GiftedAccount accountImpl) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _accountImpl = accountImpl;
    }

    function setRegistry(ERC6551Registry registry) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _registry = registry;
    }

    function setGasSponsorBook(IGasSponsorBook gasSponsorBook) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _gasSponsorBook = gasSponsorBook;
    }

    function tokenAccountAddress(uint256 tokenId) public view returns (address) {
        return _registry.account(address(_accountImpl), block.chainid, address(_giftBox), tokenId, 0);
    }

    function generateTicketID(address account) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(account)));
    }

    function safeMintAccount(address to) public payable onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 tokenId = GiftBox(_giftBox).nextTokenId();
        address tokenAccount = _registry.account(address(_accountImpl), block.chainid, address(_giftBox), tokenId, 0);
        GiftBox(_giftBox).safeMint(to);

        createAccountIfNeeded(tokenId, tokenAccount);

        handleSponsorshipAndTransfer(tokenAccount, tokenId);
    }

    function mintTransferNFT(address mintTo, address transferTo, address nft, uint256 transferTokenId)
        external
        payable
        whenNotPaused
    {
        require(IERC721(nft).ownerOf(transferTokenId) == msg.sender, "!not-owner-of-NFT");
        require(IERC721(nft).getApproved(transferTokenId) == address(this), "!not-approved-to-transfer-NFT");

        uint256 tokenId = GiftBox(_giftBox).nextTokenId();
        GiftBox(_giftBox).safeMintTransferGift(mintTo, transferTo);

        address tokenAccount = _registry.account(address(_accountImpl), block.chainid, address(_giftBox), tokenId, 0);
        createAccountIfNeeded(tokenId, tokenAccount);

        IERC721(nft).transferFrom(msg.sender, tokenAccount, transferTokenId);

        handleSponsorshipAndTransfer(tokenAccount, tokenId);

        emit MintTransferNFT(msg.sender, mintTo, nft, transferTokenId, tokenId, transferTo);
    }

    function mintTransferERC1155(
        address mintTo,
        address transferTo,
        address nft,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external payable whenNotPaused {
        require(IERC1155(nft).balanceOf(msg.sender, id) >= amount, "!not-owner-of-ERC1155");
        require(IERC1155(nft).isApprovedForAll(msg.sender, address(this)), "!not-approved-to-transfer-ERC1155");

        uint256 tokenId = GiftBox(_giftBox).nextTokenId();
        GiftBox(_giftBox).safeMintTransferGift(mintTo, transferTo);

        address tokenAccount = _registry.account(address(_accountImpl), block.chainid, address(_giftBox), tokenId, 0);
        createAccountIfNeeded(tokenId, tokenAccount);

        IERC1155(nft).safeTransferFrom(msg.sender, tokenAccount, id, amount, data);

        handleSponsorshipAndTransfer(tokenAccount, tokenId);

        emit MintTransferERC1155(msg.sender, mintTo, nft, id, amount, tokenId, transferTo);
    }

    function createAccountIfNeeded(uint256 tokenId, address tokenAccount) internal {
        if (tokenAccount.code.length == 0) {
            _registry.createAccount(
                address(_accountImpl),
                block.chainid,
                address(_giftBox),
                tokenId,
                0,
                abi.encodeWithSignature("initialize(address)", address(_guardian))
            );
        }
    }

    function handleSponsorshipAndTransfer(address tokenAccount, uint256 tokenId) internal {
        if (address(_gasSponsorBook) != address(0) && msg.value >= _gasSponsorBook.feePerSponsorTicket()) {
            uint256 sponserFee = _gasSponsorBook.feePerSponsorTicket();
            uint256 ticket = generateTicketID(address(tokenAccount));
            _gasSponsorBook.addSponsorTicket{value: sponserFee}(ticket);
            uint256 left = msg.value - sponserFee;
            if (left > 0) {
                payable(tokenAccount).sendValue(left);
                emit TransferEtherToAccount(tokenAccount, msg.sender, left);
            }
            emit SponsorEnabled(tokenAccount, tokenId, ticket);
        } else if (msg.value > 0) {
            uint256 value = msg.value;
            emit TransferEtherToAccount(tokenAccount, msg.sender, value);
            payable(tokenAccount).sendValue(value);
        }
    }

    /**
     * Adds a sponsor ticket for the given account and token ID, paying the sponsor ticket fee.
     * A sponsor ticket allows the account holder to sponsor a gas refund for transfers of the token ID.
     * The sponsor ticket ID is generated and stored in the gas sponsor book along with the sponsor funds.
     * Emits a SponsorTicketAdded event with details.
     */
    function addSponsorTicket(address account) external payable {
        require(msg.value >= _gasSponsorBook.feePerSponsorTicket(), "Insufficient funds for sponsor ticket");
        uint256 ticket = generateTicketID(account);
        _gasSponsorBook.addSponsorTicket{value: msg.value}(ticket);
        emit SponsorTicketAdded(account, ticket, msg.value);
    }

    /**
     * @dev Checks if a given NFT token has a sponsor ticket.
     * @param tokenId The ID of the NFT token.
     * @return A boolean indicating whether the NFT token has a sponsor ticket or not.
     */
    function hasSponsorTicket(uint256 tokenId) public view returns (bool) {
        if (address(_gasSponsorBook) == address(0)) {
            return false;
        }
        address tokenAccount = _registry.account(address(_accountImpl), block.chainid, address(_giftBox), tokenId, 0);
        uint256 ticket = generateTicketID(tokenAccount);
        return _gasSponsorBook.sponsorTickets(ticket) > 0;
    }

    /**
     * Transfers an ERC721 token from a GiftedAccount to another address,
     * sponsored by the original sender which adds a sponsor ticket.
     * Consumes the sponsor ticket.
     */
    function transferTokenSponsor(
        IGiftedAccount boundedAccount,
        address tokenContract,
        uint256 tokenId,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        uint256 ticket = generateTicketID(address(boundedAccount));
        require(_gasSponsorBook.sponsorTickets(ticket) > 0, "!sponsor-ticket-not-enough");
        _gasSponsorBook.consumeSponsorTicket(ticket, msg.sender);
        boundedAccount.transferToken(tokenContract, tokenId, to, deadline, v, r, s);
    }

    /**
     * @dev Transfers an ERC1155 token from a GiftedAccount to another address,
     * sponsored by the original sender which adds a sponsor ticket.
     * Consumes the sponsor ticket.
     * @param boundedAccount The GiftedAccount from which the token will be transferred.
     * @param tokenContract The address of the ERC1155 token contract.
     * @param tokenId The ID of the token to transfer.
     * @param amount The amount of tokens to transfer.
     * @param to The address to which the token will be transferred.
     * @param deadline The deadline timestamp until which the transaction is valid.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     */
    function transferToken1155Sponsor(
        IGiftedAccount boundedAccount,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        uint256 ticket = generateTicketID(address(boundedAccount));
        require(_gasSponsorBook.sponsorTickets(ticket) > 0, "!sponsor-ticket-not-enough");
        _gasSponsorBook.consumeSponsorTicket(ticket, msg.sender);
        boundedAccount.transferERC1155Token(tokenContract, tokenId, amount, to, deadline, v, r, s);
    }
}
