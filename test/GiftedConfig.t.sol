// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GiftedConfig.sol";

contract GiftedConfigTest is Test {
    GiftedConfig public config = new GiftedConfig();
    string[] _keys;
    string[] _values;

    function testConfig() public {
        _keys.push("key1");
        _values.push("value1");

        config.setConfigs(_keys, _values);

        string[] memory values = config.getConfigs(_keys);
        assertEq(values[0], "value1");
    }

    function testConfig2() public {
        config.setConfig("key2", "value2");
        assertEq(config.getConfig("key2"), "value2");
    }
}
