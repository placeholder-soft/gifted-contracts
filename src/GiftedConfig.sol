// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/access/Ownable.sol";

contract GiftedConfig is Ownable {
    mapping(string => string) public config;
    mapping(string => address) public addressConfig;

    constructor() Ownable(msg.sender) {}

    function setConfigs(string[] calldata keys, string[] calldata values) public onlyOwner {
        for (uint256 i = 0; i < keys.length; ++i) {
            config[keys[i]] = values[i];
        }
    }

    function deleteConfigs(string[] calldata keys) public onlyOwner {
        for (uint256 i = 0; i < keys.length; ++i) {
            delete config[keys[i]];
        }
    }

    function setConfig(string calldata key, string calldata value) public onlyOwner {
        config[key] = value;
    }

    function deleteConfig(string calldata key) public onlyOwner {
        delete config[key];
    }

    function getConfigs(string[] calldata keys) public view returns (string[] memory) {
        string[] memory values = new string[](keys.length);
        for (uint256 i = 0; i < keys.length; ++i) {
            values[i] = config[keys[i]];
        }
        return values;
    }

    function getConfig(string calldata key) public view returns (string memory) {
        return config[key];
    }

    function setAddressConfig(string calldata key, address value) public onlyOwner {
        addressConfig[key] = value;
    }

    function deleteAddressConfig(string calldata key) public onlyOwner {
        delete addressConfig[key];
    }

    function getAddressConfig(string calldata key) public view returns (address) {
        return addressConfig[key];
    }

    function setAddressConfigs(string[] calldata keys, address[] calldata values) public onlyOwner {
        for (uint256 i = 0; i < keys.length; ++i) {
            addressConfig[keys[i]] = values[i];
        }
    }

    function getAddressConfigs(string[] calldata keys) public view returns (address[] memory) {
        address[] memory values = new address[](keys.length);
        for (uint256 i = 0; i < keys.length; ++i) {
            values[i] = addressConfig[keys[i]];
        }
        return values;
    }

    function deleteAddressConfigs(string[] calldata keys) public onlyOwner {
        for (uint256 i = 0; i < keys.length; ++i) {
            delete addressConfig[keys[i]];
        }
    }
}
