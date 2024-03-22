// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "erc6551/ERC6551Registry.sol";
import "@openzeppelin/utils/Address.sol";
import "@openzeppelin/token/ERC1155/IERC1155.sol";

import "../src/GiftBox.sol";
import "../src/GiftedAccount.sol";
import "../src/GiftBoxAccountHelper.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import "../src/Vault.sol";
import "../src/GasSponsorBook.sol";
import "../src/mocks/MockBrightMoments.sol";
import "../src/mocks/MockERC1155.sol";

contract GiftBoxAccountHelperTest is Test {
    ERC6551Registry public registry;
    GiftBox public token;
    GiftedAccount public giftedAccount;
    GiftBoxAccountHelper public helper;
    Vault public vault;
    GasSponsorBook public sponsorBook;
    MockBrightMoments internal mockNFT = new MockBrightMoments();
    MockERC1155 internal mockERC1155 = new MockERC1155();

    using Address for address payable;

    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    function setUp() public {
        GiftedAccountGuardian guardian = new GiftedAccountGuardian();
        GiftedAccount implementation = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(implementation));

        GiftedAccountProxy proxy = new GiftedAccountProxy(address(guardian));
        giftedAccount = GiftedAccount(payable(address(proxy)));

        registry = new ERC6551Registry();
        token = new GiftBox();
        helper =
            new GiftBoxAccountHelper(GiftedAccount(giftedAccount), GiftBox(token), ERC6551Registry(registry), guardian);
        token.grantRole(token.MINTER_ROLE(), address(helper));

        vault = new Vault();
        vault.initialize(address(this));
        sponsorBook = new GasSponsorBook();
        vault.grantRole(vault.CONTRACT_ROLE(), address(sponsorBook));

        sponsorBook.setVault(vault);
        helper.setGasSponsorBook(sponsorBook);
        sponsorBook.grantRole(sponsorBook.SPONSOR_ROLE(), address(helper));
    }

    function testMintAccount() public {
        uint256 tokenId = 0;

        helper.safeMintAccount(vm.addr(1));

        address account = registry.account(address(giftedAccount), block.chainid, address(token), tokenId, 0);

        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));

        assertTrue(token.ownerOf(tokenId) == vm.addr(1));
        assertTrue(GiftedAccount(payable(account)).owner() == vm.addr(1), "account owner should be vm.addr(1)");
    }

    function testMintAccountWithToken() public {
        uint256 tokenId = 0;

        helper.safeMintAccount{value: 1000000}(vm.addr(1));

        address account = registry.account(address(giftedAccount), block.chainid, address(token), tokenId, 0);

        assertTrue(account.balance == 1000000);
    }

    function testPauseable() public {
        helper.pause();

        vm.expectRevert();
        helper.safeMintAccount(vm.addr(1));

        helper.unpause();
        helper.safeMintAccount(vm.addr(1));
        assertTrue(token.ownerOf(0) == vm.addr(1));
    }

    function testSendGiftFrom() public {
        uint256 tokenId = 0;
        helper.safeMintAccount(vm.addr(1));

        vm.prank(vm.addr(3));
        vm.expectRevert(abi.encodeWithSignature("ERC721InsufficientApproval(address,uint256)", vm.addr(3), tokenId));
        token.safeTransferGiftFrom(vm.addr(1), vm.addr(2), tokenId);

        vm.prank(vm.addr(1));
        token.safeTransferGiftFrom(vm.addr(1), vm.addr(2), tokenId);

        assertEq(token.ownerOf(tokenId), vm.addr(2));
    }

    event SponsorEnabled(address indexed account, uint256 tokenId, uint256 ticket);

    function testGasSponser() public {
        // Check initial fee per sponsor ticket and provide the contract with ether for transactions
        assertEq(sponsorBook.feePerSponsorTicket(), 0.01 ether);
        vm.deal(address(this), 0.01 ether);
        uint256 tokenId = 0;

        // Expect the SponsorEnabled event to be emitted with specified parameters
        vm.expectEmit(false, true, false, false);
        emit SponsorEnabled(
            address(0x51D820586db27D88926AE97547B7D5a9e694DfcC),
            tokenId,
            113992659723804068791975987725367440479639784254971844117679285722458161740048
        );

        // Verify that the account does not have a sponsor ticket before minting
        assertEq(helper.hasSponsorTicket(tokenId), false);

        // Mint a new account with a sponsor ticket and check balances
        helper.safeMintAccount{value: 0.01 ether}(vm.addr(1));
        assertEq(address(this).balance, 0);
        assertEq(address(sponsorBook).balance, 0);
        assertEq(address(vault).balance, 0.01 ether);

        // Verify that the account now has a sponsor ticket after minting
        assertEq(helper.hasSponsorTicket(tokenId), true);

        // Mint an NFT to the newly created GiftedAccount and verify ownership
        GiftedAccount account =
            GiftedAccount(payable(registry.account(address(giftedAccount), block.chainid, address(token), tokenId, 0)));
        mockNFT.safeMint(address(account), "");
        assertEq(mockNFT.ownerOf(0), address(account));

        // Generate a signed message for transferring the NFT and verify the signer
        string memory signMessage = account.getTransferNFTPermitMessage(address(mockNFT), 0, vm.addr(2), 1 days);
        bytes32 msgHash = account.toEthPersonalSignedMessageHash(bytes(signMessage));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, msgHash);
        address signer = ecrecover(msgHash, v, r, s);
        assertEq(signer, vm.addr(1));

        // Attempt to transfer the NFT using a sponsor ticket and expect a revert due to lack of permission
        // addr3 is sender of the sponsor ticket, which got gas funds
        assertEq(address(vm.addr(3)).balance, 0);
        vm.prank(vm.addr(3));
        vm.expectRevert("!consumer-not-permitted");
        helper.transferTokenSponsor(IGiftedAccount(account), address(mockNFT), 0, vm.addr(2), 1 days, v, r, s);

        // Grant the CONSUMER_ROLE to addr3 and perform the transfer with a sponsor ticket
        sponsorBook.grantRole(sponsorBook.CONSUMER_ROLE(), vm.addr(3));
        assertEq(address(vm.addr(3)).balance, 0);
        vm.prank(vm.addr(3));
        helper.transferTokenSponsor(IGiftedAccount(account), address(mockNFT), 0, vm.addr(2), 1 days, v, r, s);

        // Verify the balance of addr3 after the transfer and that the NFT ownership has changed
        assertEq(address(vm.addr(3)).balance, 0.01 ether);
        assertEq(mockNFT.ownerOf(0), vm.addr(2));

        // Consume the sponsor ticket and verify it's no longer available
        assertEq(helper.hasSponsorTicket(tokenId), false);
    }

    function testMintTransferNFT() public {
        // Arrange
        address minter = vm.addr(1);
        address recipient = vm.addr(2);
        uint256 tokenId = 0;
        mockNFT.safeMint(minter, "");

        vm.prank(minter);
        mockNFT.approve(address(helper), tokenId);

        // Act
        uint256 giftBoxTokenId = token.nextTokenId();
        vm.prank(minter);
        helper.mintTransferNFT(minter, recipient, address(mockNFT), tokenId);

        // Check that the account was created and linked to the GiftBox token
        address account = registry.account(address(giftedAccount), block.chainid, address(token), giftBoxTokenId, 0);
        assertTrue(account != address(0), "Account should be created");
        assertTrue(GiftedAccount(payable(account)).owner() == recipient, "Account owner should be the recipient");

        // Check that the artwork NFT was transferred to the recipient
        assertEq(mockNFT.ownerOf(tokenId), account, "Artwork NFT should be transferred to the recipient");

        // Check that the GiftBox token was transferred to the recipient
        assertEq(token.ownerOf(giftBoxTokenId), recipient, "GiftBox token should be transferred to the recipient");
    }

    function testMintTransferERC1155() public {
        uint256 tokenId = 0;
        uint256 amount = 10;
        address minter = vm.addr(1);
        address to = vm.addr(2); // The recipient of the token

        address account = registry.account(address(giftedAccount), block.chainid, address(token), tokenId, 0);
        // Mint ERC1155 tokens to the test contract
        mockERC1155.mint(minter, tokenId, amount, "");

        // Approve the account helper to transfer the specified amount of tokens
        vm.prank(minter);
        mockERC1155.setApprovalForAll(address(helper), true);

        // Expect the TransferSingle event to be emitted with the correct details
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(helper), minter, account, tokenId, amount);

        // Call the method to mint and transfer the ERC1155 token
        vm.prank(minter);
        helper.mintTransferERC1155(minter, to, address(mockERC1155), tokenId, amount, "");

        // Check that the recipient now owns the correct amount of tokens
        assertEq(mockERC1155.balanceOf(account, tokenId), amount);

        // Check that the test contract no longer owns the tokens
        assertEq(mockERC1155.balanceOf(address(this), tokenId), 0);
    }
}
