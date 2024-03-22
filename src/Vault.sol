// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/Pausable.sol";
import "@openzeppelin/access/AccessControl.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "./ERC20Wad.sol";
import "./interfaces/IVault.sol";

/// @title Vault
/// @notice Storage of protocol funds
contract Vault is Pausable, AccessControl, ReentrancyGuard, IVault {
    uint8 private _initialized;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    /// Libraries
    using Address for address payable;

    /// events
    event TransferIn(address indexed asset, address indexed from, uint256 amount);
    event TransferOut(address indexed asset, address indexed to, uint256 amount);

    constructor() {}

    function initialize(address owner) external {
        require(_initialized == 0, "!already-initialized");
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(CONTRACT_ROLE, owner);
        _initialized = 1;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Transfers `amount` of `asset` in
    /// @dev Only callable by other protocol contracts
    /// @param asset Asset address, e.g. address(0) for ETH
    /// @param from Address where asset is transferred from
    function transferIn(address asset, address from, uint256 amount)
        external
        payable
        whenNotPaused
        onlyRole(CONTRACT_ROLE)
    {
        if (amount != 0 && asset != address(0)) {
            ERC20Wad.wad_safeTransferFrom(IERC20Metadata(asset), from, address(this), amount);
        }
        emit TransferIn(asset, from, amount);
    }

    /// @notice Transfers `amount` of `asset` out
    /// @dev Only callable by other protocol contracts
    /// @param asset Asset address, e.g. address(0) for ETH
    /// @param to Address where asset is transferred to
    function transferOut(address asset, address to, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyRole(CONTRACT_ROLE)
    {
        if (amount != 0 && to != address(0)) {
            if (asset == address(0)) {
                payable(to).sendValue(amount);
            } else {
                ERC20Wad.wad_safeTransfer(IERC20Metadata(asset), to, amount);
            }
        }
        emit TransferOut(asset, to, amount);
    }
}
