// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title IGsm
 * @author Aave
 * @notice Defines the behaviour of a Gsm Token
 */
interface IGsmToken is IAccessControl, IERC20 {
  /**
   * @notice Returns the identifier of the Minter Role
   * @return The bytes32 id hash of the Minter role
   */
  function MINTER_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the underlying asset backing the GsmToken
   * @return The address of the underlying asset
   */
  function UNDERLYING_ASSET() external view returns (address);

  /**
   * @notice Creates `amount` new tokens for `account`
   * @param account The address to create tokens for
   * @param amount The amount of tokens to create
   */
  function mint(address account, uint256 amount) external;

  /**
   * @notice Destroys `amount` tokens from caller
   * @param amount The amount of tokens to destroy
   */
  function burn(uint256 amount) external;
}
