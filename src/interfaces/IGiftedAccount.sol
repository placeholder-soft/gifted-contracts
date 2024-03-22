// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IGiftedAccountGuardian.sol";

interface IGiftedAccount {
    function isOwner(address caller) external view returns (bool);
    function getGuardian() external view returns (IGiftedAccountGuardian);

    function setAccountGuardian(address guardian) external;

    function transferToken(
        address tokenContract,
        uint256 tokenId,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function transferERC1155Token(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
