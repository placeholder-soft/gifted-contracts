// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface IVault {
    function transferIn(address asset, address from, uint256 amount) external payable;
    function transferOut(address asset, address to, uint256 amount) external;
}
