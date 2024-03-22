// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IGiftedAccountGuardian {
    event Upgraded(address indexed implementation);
    event ExecutorUpdated(address executor, bool trusted);

    function isExecutor(address executor) external view returns (bool);

    function setExecutor(address executor, bool trusted) external;

    function getImplementation() external view returns (address);

    function getCustomAccountImplementation(address account) external view returns (address);
    function setGiftedAccountImplementation(address newImplementation) external;
}
