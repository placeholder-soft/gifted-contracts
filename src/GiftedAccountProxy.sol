// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/proxy/Proxy.sol";

import "./interfaces/IGiftedAccountGuardian.sol";

error InvalidImplementation();

contract GiftedAccountProxy is Proxy {
    IGiftedAccountGuardian immutable _accountGuardian;

    constructor(address implementation) Proxy() {
        if (implementation == address(0) || IGiftedAccountGuardian(implementation).getImplementation() == address(0)) {
            revert InvalidImplementation();
        }

        _accountGuardian = IGiftedAccountGuardian(implementation);
    }

    // @dev account implementation, if set, overrides the implementation set in the constructor.
    // the override can only be controlled by the token holder, not the proxy itself or account guardian.
    // @return address of the implementation
    function _implementation() internal view virtual override returns (address) {
        address customImpl = _accountGuardian.getCustomAccountImplementation(address(this));
        if (customImpl != address(0)) {
            return customImpl;
        }

        return _accountGuardian.getImplementation();
    }
}
