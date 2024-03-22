// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../src/GiftedAccount.sol";

contract MockGiftedAccount is GiftedAccount {
    constructor() GiftedAccount() {}

    function customFunction() external pure returns (uint256) {
        return 12345;
    }
}
