// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "erc6551/ERC6551Registry.sol";
import "../src/GiftBox.sol";
import "../src/GiftedAccount.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";

import "../src/mocks/MockBrightMoments.sol";
import "../src/mocks/MockERC1155.sol";

contract GiftedAccountTest is Test {
    ERC6551Registry internal registry;
    GiftBox internal giftBox = new GiftBox();
    GiftedAccount internal giftedAccount;
    MockBrightMoments internal mockNFT = new MockBrightMoments();
    MockERC1155 internal mockERC1155 = new MockERC1155();

    function setUp() public {
        GiftedAccountGuardian guardian = new GiftedAccountGuardian();
        GiftedAccount implementation = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(implementation));

        GiftedAccountProxy proxy = new GiftedAccountProxy(address(guardian));
        giftedAccount = GiftedAccount(payable(address(proxy)));

        registry = new ERC6551Registry();
    }

    function testDeploy() public {
        address deployedAccount = registry.createAccount(address(giftedAccount), block.chainid, address(0), 0, 0, "");

        assertTrue(deployedAccount != address(0));

        address predictedAccount = registry.account(address(giftedAccount), block.chainid, address(0), 0, 0);

        assertEq(predictedAccount, deployedAccount);
    }

    function testCallDirectly() public {
        uint256 tokenId = 0;
        giftBox.safeMint(vm.addr(1));

        address account =
            registry.createAccount(address(giftedAccount), block.chainid, address(giftBox), tokenId, 0, "");

        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));

        IERC6551Account accountInstance = IERC6551Account(payable(account));

        assertEq(accountInstance.owner(), vm.addr(1));

        vm.deal(account, 1 ether);

        vm.prank(vm.addr(1));
        accountInstance.executeCall(payable(vm.addr(2)), 0.5 ether, "");

        assertEq(account.balance, 0.5 ether);
        assertEq(vm.addr(2).balance, 0.5 ether);
        assertEq(accountInstance.nonce(), 1);

        vm.prank(vm.addr(1));
        giftBox.transferFrom(vm.addr(1), vm.addr(2), tokenId);
        assertEq(accountInstance.owner(), vm.addr(2));

        vm.prank(vm.addr(1));
        vm.expectRevert(NotAuthorized.selector);
        accountInstance.executeCall(payable(vm.addr(2)), 0.5 ether, "");

        vm.prank(vm.addr(2));
        accountInstance.executeCall(payable(vm.addr(2)), 0.5 ether, "");
        assertEq(vm.addr(2).balance, 1 ether);
        assertEq(accountInstance.nonce(), 2);
    }

    function testCallWithPermit() public {
        uint256 tokenId = 0;
        giftBox.safeMint(vm.addr(1));

        address account =
            registry.createAccount(address(giftedAccount), block.chainid, address(giftBox), tokenId, 0, "");

        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));
        vm.deal(account, 1 ether);
        assertEq(account.balance, 1 ether);

        GiftedAccount tokenAccount = GiftedAccount(payable(account));
        bytes32 digest = tokenAccount.getTypedCallPermitHash(vm.addr(2), 0.5 ether, "", 1 days);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);

        // wrong param will yield invalid signature
        vm.prank(vm.addr(10000));
        vm.expectRevert("!call-permit-invalid-signature");
        tokenAccount.executeTypedCallPermit(vm.addr(2), 0.4 ether, "", 1 days, v, r, s);

        vm.prank(vm.addr(100));
        tokenAccount.executeTypedCallPermit(vm.addr(2), 0.5 ether, "", 1 days, v, r, s);

        assertEq(account.balance, 0.5 ether);
        assertEq(vm.addr(2).balance, 0.5 ether);

        // can only use signature once
        vm.prank(vm.addr(10000));
        vm.expectRevert("!call-permit-invalid-signature");
        tokenAccount.executeTypedCallPermit(vm.addr(2), 0.5 ether, "", 1 days, v, r, s);
    }

    // function testTrnsferNFTPermitMessage() public {
    //     assertEq(giftedAccount.getTransferNFTPermitMessage(vm.addr(1), 10, vm.addr(2), 1 days), "");
    // }

    function testTransferERC721UsingPermit() public {
        uint256 giftBoxTokenId = 0;
        giftBox.safeMint(vm.addr(1));

        address account =
            registry.createAccount(address(giftedAccount), block.chainid, address(giftBox), giftBoxTokenId, 0, "");

        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));

        GiftedAccount tokenAccount = GiftedAccount(payable(account));
        assertEq(tokenAccount.owner(), vm.addr(1));

        uint256 artworkTokenID = 0;
        mockNFT.safeMint(address(tokenAccount), "");

        string memory signMessage =
            tokenAccount.getTransferNFTPermitMessage(address(mockNFT), artworkTokenID, vm.addr(2), 1 days);
        bytes32 msgHash = tokenAccount.toEthPersonalSignedMessageHash(bytes(signMessage));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, msgHash);

        address signer = ecrecover(msgHash, v, r, s);
        assertEq(signer, vm.addr(1));

        vm.prank(vm.addr(3));
        tokenAccount.transferToken(address(mockNFT), artworkTokenID, vm.addr(2), 1 days, v, r, s);

        assertEq(mockNFT.ownerOf(giftBoxTokenId), vm.addr(2));
        assertEq(tokenAccount.owner(), vm.addr(1));
    }

    function testTransferERC1155UsingPermit() public {
        uint256 giftBoxTokenId = 0;
        uint256 amount = 2; // Amount of the ERC1155 token to transfer
        uint256 nonce = 0; // Nonce used for the permit
        giftBox.safeMint(vm.addr(1));

        address account =
            registry.createAccount(address(giftedAccount), block.chainid, address(giftBox), giftBoxTokenId, nonce, "");

        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));

        GiftedAccount tokenAccount = GiftedAccount(payable(account));
        assertEq(tokenAccount.owner(), vm.addr(1));

        uint256 artworkTokenID = 0;
        mockERC1155.mint(address(tokenAccount), artworkTokenID, amount, "");

        // Construct the permit message
        string memory signMessage = tokenAccount.getTransferERC1155PermitMessage(
            address(mockERC1155), artworkTokenID, amount, vm.addr(2), 1 days
        );
        bytes32 msgHash = tokenAccount.toEthPersonalSignedMessageHash(bytes(signMessage));

        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, msgHash);

        // Execute the transfer with the permit
        vm.prank(vm.addr(1));
        tokenAccount.transferERC1155Token(address(mockERC1155), artworkTokenID, amount, vm.addr(2), 1 days, v, r, s);

        // Verify the transfer
        assertEq(mockERC1155.balanceOf(vm.addr(2), artworkTokenID), amount);
        assertEq(mockERC1155.balanceOf(address(tokenAccount), artworkTokenID), 0);
    }
}
