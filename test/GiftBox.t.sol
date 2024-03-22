// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GiftBox.sol";
import "../src/mocks/MockBrightMoments.sol";
import "@openzeppelin/utils/Strings.sol";
import "../src/GiftBoxAccountHelper.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";

contract GiftBoxTest is Test {
    GiftBox public token;
    GiftedAccount public giftedAccount;
    ERC6551Registry public registry;
    MockBrightMoments public artworkNFT;
    GiftBoxAccountHelper public accountHelper;
    GiftedAccountGuardian public guardian;

    using Strings for address;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event GiftSent(address indexed from, address indexed to, uint256 tokenId);

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public {
        guardian = new GiftedAccountGuardian();
        GiftedAccount implementation = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(implementation));
        GiftedAccountProxy proxy = new GiftedAccountProxy(address(guardian));
        giftedAccount = GiftedAccount(payable(address(proxy)));

        token = new GiftBox();
        token.setBaseURI("https://token.gifted.art/");
        registry = new ERC6551Registry();

        accountHelper =
            new GiftBoxAccountHelper(GiftedAccount(giftedAccount), GiftBox(token), ERC6551Registry(registry), guardian);
        token.grantRole(token.MINTER_ROLE(), address(accountHelper));

        artworkNFT = new MockBrightMoments();
    }

    function testMint() public {
        token.safeMint(address(this));
        assertEq(token.balanceOf(address(this)), 1);
    }

    function testMintIncremental() public {
        token.safeMint(address(this));
        assertEq(token.balanceOf(address(this)), 1);
        token.safeMint(address(this));
        token.safeMint(address(this));

        assertEq(token.balanceOf(address(this)), 3);
        assertEq(token.ownerOf(2), address(this));
    }

    function testTokenURI() public {
        token.safeMint(address(this));

        assertEq(token.tokenURI(0), "https://token.gifted.art/0");
    }

    function testTokenBalanceURI() public {
        token.safeMint(address(this));

        address account = registry.account(address(giftedAccount), block.chainid, address(token), 0, 0);

        assertEq(token.tokenURI(0), "https://token.gifted.art/0");

        vm.deal(account, 1.1 ether);
        token.safeMint(address(this));
        assertEq(token.tokenURI(1), "https://token.gifted.art/1");
    }

    function testMintTransferNFT() public {
        // address(this) === address of external wallet
        // vm.addr(1) === address of privi embemdded wallet
        address externalWallet = address(this);
        address privyAddr = vm.addr(1);
        address receiptAddr = vm.addr(2);

        artworkNFT.safeMint(address(this), "");
        artworkNFT.approve(address(accountHelper), 0); // front end call 1st
        assertEq(artworkNFT.ownerOf(0), externalWallet);

        vm.expectEmit();
        emit Transfer(address(0), privyAddr, 0);
        vm.expectEmit();
        emit Transfer(privyAddr, receiptAddr, 0);

        accountHelper.mintTransferNFT(privyAddr, receiptAddr, address(artworkNFT), 0); // front end call 2nd

        assertEq(token.balanceOf(privyAddr), 0);
        assertEq(token.ownerOf(0), receiptAddr);

        assertEq(artworkNFT.ownerOf(0), accountHelper.tokenAccountAddress(0));
    }

    function testClawback() public {
        // mint giftbox
        token.safeMint(vm.addr(1));
        assertEq(token.ownerOf(0), vm.addr(1));

        // can not clawback mint token
        vm.expectRevert("from address is zero address");
        token.clawback(0);

        // update threshold
        token.updateClawbackThreshold(7 days);
        assertEq(token._clawbackThreshold(), 7 days);

        // can not clawback non-mint token
        vm.expectRevert("token does not exist");
        token.clawback(999);

        // transfer giftbox
        vm.prank(vm.addr(1));
        vm.expectEmit(true, true, false, false);
        emit GiftSent(vm.addr(1), vm.addr(2), 0);
        token.safeTransferGiftFrom(vm.addr(1), vm.addr(2), 0);
        assertEq(token.ownerOf(0), vm.addr(2));

        // can not clawback if not previous sender
        vm.expectRevert("sender is not the from address");
        token.clawback(0);

        // ok clawback
        vm.prank(vm.addr(1));
        token.clawback(0);
        assertEq(token.ownerOf(0), vm.addr(1));

        // no recursived clawback
        vm.prank(vm.addr(2));
        vm.expectRevert("from address is zero address");
        token.clawback(0);
    }

    function testClawbackTime() public {
        // mint giftbox
        token.safeMint(vm.addr(1));
        assertEq(token.ownerOf(0), vm.addr(1));

        // transfer giftbox
        vm.prank(vm.addr(1));
        token.safeTransferGiftFrom(vm.addr(1), vm.addr(2), 0);
        assertEq(token.ownerOf(0), vm.addr(2));

        vm.warp(block.timestamp + 30 days + 1);
        vm.expectRevert("clawback time expired");
        vm.prank(vm.addr(1));
        token.clawback(0);
    }

    function testClawbackAndResend() public {
        // mint giftbox
        token.safeMint(vm.addr(1));
        assertEq(token.ownerOf(0), vm.addr(1));

        // transfer giftbox
        vm.prank(vm.addr(1));
        token.safeTransferGiftFrom(vm.addr(1), vm.addr(2), 0);
        assertEq(token.ownerOf(0), vm.addr(2));

        // can not resent to the same address
        vm.prank(vm.addr(1));
        vm.expectRevert("to address is the same as the last transfer to address");
        token.clawback(0, vm.addr(2));

        // ok clawback
        vm.prank(vm.addr(1));
        vm.expectEmit(true, true, true, false);
        emit GiftSent(vm.addr(1), vm.addr(3), 0);
        token.clawback(0, vm.addr(3));
        assertEq(token.ownerOf(0), vm.addr(3));
    }

    function testNotAbuseClawback() public {
        // mint giftbox -> 1
        token.safeMint(vm.addr(1));
        assertEq(token.ownerOf(0), vm.addr(1));

        // sendGift giftbox:  1 -> 2
        vm.prank(vm.addr(1));
        token.safeTransferGiftFrom(vm.addr(1), vm.addr(2), 0);
        assertEq(token.ownerOf(0), vm.addr(2));

        // transfer giftbox: 2 -> 3
        vm.prank(vm.addr(2));
        token.safeTransferFrom(vm.addr(2), vm.addr(3), 0);

        // clawback giftbox failed due to use of safeTransferFrom and not using safeTransferGiftFrom
        vm.prank(vm.addr(1));
        vm.expectRevert();
        token.clawback(0, vm.addr(4));

        // sendgift giftbox: 3 -> 4
        vm.prank(vm.addr(3));
        token.safeTransferGiftFrom(vm.addr(3), vm.addr(4), 0);

        // clawback giftbox: 4 -> 3 -> 5
        vm.prank(vm.addr(3));
        token.clawback(0, vm.addr(5));
        assertEq(token.ownerOf(0), vm.addr(5));
    }
}
