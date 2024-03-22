// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/access/Ownable.sol";
import "../src/GiftedConfig.sol";
import "../src/GiftBoxAccountHelper.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import "./mocks/MockGiftedAccount.sol";

contract UpgradableTest is Test {
    GiftedAccountProxy public proxy;
    GiftedAccount implementation;

    ERC6551Registry public registry;
    GiftedAccountGuardian public guardian;

    GiftBox public giftbox;

    function setUp() public {
        guardian = new GiftedAccountGuardian();
        implementation = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(implementation));

        proxy = new GiftedAccountProxy(address(guardian));

        registry = new ERC6551Registry();

        giftbox = new GiftBox();
    }

    function testConfigUpgrade() public {
        uint256 tokenId = 0;
        address user1 = vm.addr(1);

        giftbox.safeMint(user1);
        assertEq(giftbox.ownerOf(tokenId), user1);

        address accountAddress = registry.createAccount(address(proxy), block.chainid, address(giftbox), tokenId, 0, "");
        vm.prank(user1);
        vm.expectRevert();
        MockGiftedAccount(payable(accountAddress)).customFunction();

        MockGiftedAccount upgradedImplementation = new MockGiftedAccount();

        vm.prank(user1);
        vm.expectRevert();
        guardian.setGiftedAccountImplementation(address(upgradedImplementation));

        guardian.setGiftedAccountImplementation(address(upgradedImplementation));

        vm.prank(user1);
        uint256 returnValue = MockGiftedAccount(payable(accountAddress)).customFunction();

        assertEq(returnValue, 12345);
    }
}
