// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/access/Ownable2Step.sol";
import "@openzeppelin/utils/Address.sol";
import "./interfaces/IGiftedAccountGuardian.sol";
import "./interfaces/IGiftedAccount.sol";

contract GiftedAccountGuardian is Ownable2Step, IGiftedAccountGuardian {
    mapping(address => bool) private _isExecutor;
    address private _implementation;

    mapping(address => address) _customAccountImplementation;

    event CustomAccountImplementationUpdated(address indexed account, address implementation);

    constructor() Ownable(msg.sender) {}

    function setExecutor(address executor, bool trusted) external onlyOwner {
        _isExecutor[executor] = trusted;
        emit ExecutorUpdated(executor, trusted);
    }

    // @dev set new implementation address
    // note that we don't call any upgrade initialization function
    // which leave it to the owner to call it
    function setGiftedAccountImplementation(address newImplementation) external onlyOwner {
        require(newImplementation.code.length > 0, "!newImplementation-is-not-a-contract");
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function getImplementation() external view returns (address) {
        return _implementation;
    }

    function isExecutor(address executor) external view returns (bool) {
        if (_isExecutor[executor]) return true;
        if (executor == owner()) return true;
        return false;
    }

    // @dev this function can only be called by the owner of the token,
    // not by anyone else, even if they are an executor, which yield the
    // control to the token holder.
    function setCustomAccountImplementation(address account, address implementation) external {
        require(
            implementation != address(0) && implementation.code.length != 0, "!implementation-is-not-a-contract-or-zero"
        );
        require(IGiftedAccount(account).isOwner(msg.sender));
        _customAccountImplementation[account] = implementation;
        emit CustomAccountImplementationUpdated(account, implementation);
    }

    function getCustomAccountImplementation(address account) external view returns (address) {
        return _customAccountImplementation[account];
    }
}
