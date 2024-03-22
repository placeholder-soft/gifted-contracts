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
import "./mocks/MockGiftedAccount.sol";
import "erc6551/interfaces/IERC6551Account.sol";

contract GiftedAccountGuardianTest is Test {
    ERC6551Registry internal registry;
    GiftBox internal token = new GiftBox();
    GiftedAccount internal giftedAccount;
    MockBrightMoments internal mockNFT = new MockBrightMoments();
    GiftedAccountGuardian internal guardian = new GiftedAccountGuardian();

    function setUp() public {
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

    function testRemoveGuardian() public {
        uint256 tokenId = 0;
        token.safeMint(vm.addr(1));

        address account = registry.createAccount(
            address(giftedAccount),
            block.chainid,
            address(token),
            tokenId,
            0,
            abi.encodeWithSignature("initialize(address)", address(guardian))
        );

        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));
        assertTrue(address(IGiftedAccount(account).getGuardian()) == address(guardian));

        vm.deal(account, 1 ether);

        // token owner is able to transfer
        assertEq(vm.addr(2).balance, 0 ether);
        vm.prank(vm.addr(1));
        IERC6551Account(payable(account)).executeCall(payable(vm.addr(2)), 0.1 ether, "");
        assertEq(vm.addr(2).balance, 0.1 ether);

        // guardian is able to execute using configed executor
        guardian.setExecutor(vm.addr(60), true);
        assertEq(vm.addr(3).balance, 0 ether);
        vm.prank(vm.addr(60));
        IERC6551Account(payable(account)).executeCall(payable(vm.addr(3)), 0.1 ether, "");
        assertEq(vm.addr(3).balance, 0.1 ether);

        // project guardian is not able to set account's guardian
        vm.prank(vm.addr(60));
        vm.expectRevert(NotAuthorized.selector);
        IGiftedAccount(account).setAccountGuardian(address(0));

        // only token owner is able to set guardian
        vm.prank(vm.addr(1));
        IGiftedAccount(account).setAccountGuardian(address(0));
        // after setting guardian, project guardian is not able to execute
        vm.prank(vm.addr(60));
        vm.expectRevert(NotAuthorized.selector);
        IERC6551Account(payable(account)).executeCall(payable(vm.addr(3)), 0.1 ether, "");
    }

    function testOwnerUseCustomImplementation() public {
        uint256 tokenId = 0;
        token.safeMint(vm.addr(1));

        address account = registry.createAccount(
            address(giftedAccount),
            block.chainid,
            address(token),
            tokenId,
            0,
            abi.encodeWithSignature("initialize(address)", address(guardian))
        );

        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));
        assertTrue(address(IGiftedAccount(account).getGuardian()) == address(guardian));

        vm.deal(account, 1 ether);

        // revert due to unauthorized function
        vm.prank(vm.addr(40));
        vm.expectRevert();
        MockGiftedAccount(payable(account)).customFunction();

        MockGiftedAccount upgradedImplementation = new MockGiftedAccount();
        // deployer is not able to upgrade
        vm.expectRevert();
        guardian.setCustomAccountImplementation(account, address(upgradedImplementation));

        // executor is not able to upgrade
        guardian.setExecutor(vm.addr(60), true);
        vm.prank(vm.addr(60));
        vm.expectRevert();
        guardian.setCustomAccountImplementation(account, address(upgradedImplementation));

        // token owner is able to upgrade account to a custom implementation
        vm.prank(vm.addr(1));
        guardian.setCustomAccountImplementation(account, address(upgradedImplementation));

        // runs ok after upgrade
        uint256 returnValue = MockGiftedAccount(payable(account)).customFunction();
        assertEq(returnValue, 12345);
    }

    function testGraduateAccount() public {
        uint256 tokenId = 0;
        token.safeMint(vm.addr(1));

        address account = registry.createAccount(
            address(giftedAccount),
            block.chainid,
            address(token),
            tokenId,
            0,
            abi.encodeWithSignature("initialize(address)", address(guardian))
        );

        MockGiftedAccount upgradedImplementation = new MockGiftedAccount();

        // deployer is not able to set impl on owner's behalf
        vm.expectRevert();
        guardian.setCustomAccountImplementation(account, address(upgradedImplementation));

        // deployer is not able to set account's guardian on owner's behalf
        vm.expectRevert();
        vm.expectRevert();
        IGiftedAccount(account).setAccountGuardian(address(0));

        // after set a custom implementation (it can be existing or new) and set guardian to address(0)
        // the account graduated to be controlled only by the token holder.
        vm.prank(vm.addr(1));
        guardian.setCustomAccountImplementation(account, address(upgradedImplementation));

        vm.prank(vm.addr(1));
        IGiftedAccount(account).setAccountGuardian(address(0));
    }

    function testEmergencyCall() public {
        uint256 tokenId = 0;
        token.safeMint(vm.addr(1));

        address account = registry.createAccount(
            address(giftedAccount),
            block.chainid,
            address(token),
            tokenId,
            0,
            abi.encodeWithSignature("initialize(address)", address(guardian))
        );

        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));
        assertTrue(address(IGiftedAccount(account).getGuardian()) == address(guardian));

        vm.deal(account, 1 ether);

        // guardian is able to execute using configed executor
        guardian.setExecutor(vm.addr(60), true);

        // mint any gift NFT to account
        token.safeMint(account);
        assertEq(token.balanceOf(account), 1);
        assertEq(token.ownerOf(1), account);

        // emergency call
        vm.prank(vm.addr(60));
        IERC6551Account(payable(account)).executeCall(
            address(token),
            0,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", address(account), vm.addr(3), 1)
        );

        assertEq(token.balanceOf(vm.addr(3)), 1);
        assertEq(token.ownerOf(1), vm.addr(3));
    }
}
