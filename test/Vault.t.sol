// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Vault.sol";
import "./mocks/MockERC20.sol";

contract VaultTest is Test {
    Vault public vault;
    MockERC20 public mockERC20;

    receive() external payable {}

    function setUp() public {
        vault = new Vault();
        vault.initialize(address(this));
        mockERC20 = new MockERC20();
    }

    function testTransferInETH() public {
        // Arrange
        address asset = address(0);
        address from = address(this);
        uint256 amount = 100;

        // Act
        vault.transferIn{value: amount}(asset, from, amount);

        // Assert
        uint256 balance = address(vault).balance;
        assertEq(balance, amount);
    }

    function test_transferIn_ERC20() external {
        // Arrange
        address asset = address(mockERC20);
        address from = address(this);
        uint256 amount = 100;
        mockERC20.mint(from, amount);
        mockERC20.approve(address(vault), amount);

        // Act
        vault.transferIn(asset, from, amount);

        // Assert
        uint256 balance = mockERC20.balanceOf(address(vault));
        assertEq(balance, amount);
    }

    function test_transferOut_ETH() external {
        // Arrange
        address asset = address(0);
        address to = address(this);
        uint256 amount = 100;
        vault.transferIn{value: amount}(asset, address(this), amount);

        // Act
        vault.transferOut(asset, to, amount);

        // Assert
        uint256 balance = address(vault).balance;
        assertEq(balance, 0);
    }

    function test_transferOut_ERC20() external {
        // Arrange
        address asset = address(mockERC20);
        address to = address(this);
        uint256 amount = 100;
        mockERC20.mint(address(this), amount);
        mockERC20.approve(address(vault), amount);
        vault.transferIn(asset, address(this), amount);

        // Act
        vault.transferOut(asset, to, amount);

        // Assert
        uint256 balance = mockERC20.balanceOf(to);
        assertEq(balance, amount);
    }
}
