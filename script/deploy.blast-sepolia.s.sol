// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GiftBox.sol";
import "../src/GiftedConfig.sol";
import "../src/GiftBoxAccountHelper.sol";
import "../src/FakeUSDC.sol";
import "../src/GiftedNFTFactory.sol";
import "../src/mocks/MockBrightMoments.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import "../src/GiftedAccount.sol";
import "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/utils/Strings.sol";

contract DeployGoerli is Script {
    using Strings for address;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /**
         * deplay gift token and helper
         */
        GiftedAccountGuardian guardian = new GiftedAccountGuardian();
        GiftedAccount implementation = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(implementation));
        GiftedAccountProxy proxy = new GiftedAccountProxy(address(guardian));
        GiftedAccount giftedAccount = GiftedAccount(payable(address(proxy)));
        giftedAccount.initialize(address(guardian));
        implementation.initialize(address(guardian));

        GiftBox giftBox = new GiftBox();
        giftBox.setBaseURI("https://token.gifted.art/");

        ERC6551Registry registry = new ERC6551Registry();
        GiftBoxAccountHelper accountHelper = new GiftBoxAccountHelper(
            GiftedAccount(implementation), GiftBox(giftBox), ERC6551Registry(registry), guardian
        );
        giftBox.grantRole(giftBox.MINTER_ROLE(), address(accountHelper));

        GiftedConfig config = new GiftedConfig();

        string[] memory keys = new string[](6);
        keys[0] = "GiftBox";
        keys[1] = "GiftBoxAccountHelper";
        keys[2] = "GiftedAccountGuardian";
        keys[3] = "GiftedAccount";
        keys[4] = "ERC6551Registry";
        keys[5] = "GiftedAccountProxy";

        address[] memory values = new address[](6);
        values[0] = address(giftBox);
        values[1] = address(accountHelper);
        values[2] = address(guardian);
        values[3] = address(giftedAccount);
        values[4] = address(registry);
        values[5] = address(proxy);

        config.setAddressConfigs(keys, values);

        vm.stopBroadcast();
    }
}
