// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library ERC20Wad {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for ERC20Burnable;

    function wad_safeTransfer(IERC20Metadata _token, address _to, uint256 _amount) internal {
        if (_amount > 0) {
            _token.safeTransfer(_to, _amount / (10 ** (18 - _token.decimals())));
        }
    }

    function wad_safeTransferFrom(IERC20Metadata _token, address _from, address _to, uint256 _amount) internal {
        if (_amount > 0) {
            _token.safeTransferFrom(_from, _to, _amount / (10 ** (18 - _token.decimals())));
        }
    }

    function wad_balanceOf(IERC20Metadata _token, address _owner) internal view returns (uint256) {
        return _token.balanceOf(_owner) * (10 ** (18 - _token.decimals()));
    }

    function wad_totalSupply(IERC20Metadata _token) internal view returns (uint256) {
        return _token.totalSupply() * (10 ** (18 - _token.decimals()));
    }

    function wad_allowance(IERC20Metadata _token, address _owner, address _spender) internal view returns (uint256) {
        return _token.allowance(_owner, _spender) * (10 ** (18 - _token.decimals()));
    }

    function wad_forceApprove(IERC20Metadata _token, address _spender, uint256 _amount) internal returns (bool) {
        _token.forceApprove(_spender, _amount / (10 ** (18 - _token.decimals())));
        return true;
    }

    function wad_safeIncreaseAllowance(IERC20Metadata _token, address _spender, uint256 _addedValue)
        internal
        returns (bool)
    {
        _token.safeIncreaseAllowance(_spender, _addedValue / (10 ** (18 - _token.decimals())));
        return true;
    }

    function wad_safeDecreaseAllowance(IERC20Metadata _token, address _spender, uint256 _subtractedValue)
        internal
        returns (bool)
    {
        _token.safeDecreaseAllowance(_spender, _subtractedValue / (10 ** (18 - _token.decimals())));
        return true;
    }

    function wad_burn(ERC20Burnable _token, uint256 _amount) internal {
        _token.burn(_amount / (10 ** (18 - _token.decimals())));
    }

    function wad_burnFrom(ERC20Burnable _token, address _from, uint256 _amount) internal {
        _token.burnFrom(_from, _amount / (10 ** (18 - _token.decimals())));
    }
}
