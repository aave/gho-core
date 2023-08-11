// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {ERC20} from '../../../gho/ERC20.sol';
import {IGsmToken} from './interfaces/IGsmToken.sol';

/**
 * @title GsmToken
 * @author Aave
 * @notice GHO Stability Module Token. It serves as a tokenized version of the underlying asset of a GSM.
 * @dev Mint and burn functions are callable by Minter entities, typically, GSM contracts.
 */
contract GsmToken is AccessControl, ERC20, IGsmToken {
  /// @inheritdoc IGsmToken
  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

  /// @inheritdoc IGsmToken
  address public immutable UNDERLYING_ASSET;

  /**
   * @notice Constructor
   * @param admin The address of the default admin role
   * @param name The name of the token
   * @param symbol The symbol of the token
   * @param decimals Decimals of the token
   * @param underlyingAsset The address of the underlying asset that will back a GsmToken
   */
  constructor(
    address admin,
    string memory name,
    string memory symbol,
    uint8 decimals,
    address underlyingAsset
  ) ERC20(name, symbol, decimals) {
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    UNDERLYING_ASSET = underlyingAsset;
  }

  /// @inheritdoc IGsmToken
  function mint(address account, uint256 amount) external onlyRole(MINTER_ROLE) {
    _mint(account, amount);
  }

  /// @inheritdoc IGsmToken
  function burn(uint256 amount) external onlyRole(MINTER_ROLE) {
    _burn(msg.sender, amount);
  }
}
