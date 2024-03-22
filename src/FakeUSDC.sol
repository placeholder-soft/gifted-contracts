// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/access/Ownable.sol";

contract FakeUSDCToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Fake USDC Token", "FUSDC") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
