// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GiftedConfig.sol";

contract DeployGiftBox is Script {
    string[] keys;
    string[] values;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        keys.push("GiftedAccount");
        values.push("0xc6e49fa9899D7Dd57945775dc48370d78b96A1F3");

        keys.push("AccountRegistry");
        values.push("0x4f449d9247Cc03cD612F7bCD66BA20A356A96de0");

        keys.push("GiftBox");
        values.push("0xB7d030F7c6406446e703E73B3d1dd8611A2D87b6");

        GiftedConfig(0x6F66edA9fcFa7Cc5FaB9A81f636613c7Cd283d39).setConfigs(keys, values);

        vm.stopBroadcast();
    }
}
