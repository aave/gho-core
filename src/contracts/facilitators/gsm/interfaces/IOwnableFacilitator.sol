// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IOwnableFacilitator
 * @author Aave/TokenLogic
 * @notice Defines the behaviour of an OwnableFacilitator
 */
interface IOwnableFacilitator {
  /**
   * @notice Mint an amount of GHO to an address
   * @dev Only callable by the owner of the Facilitator.
   * @param account The address receiving GHO
   * @param amount The amount of GHO to be minted
   */
  function mint(address account, uint256 amount) external;

  /**
   * @notice Burns an amount of GHO
   * @dev Only callable by the owner of the Facilitator.
   * @param amount The amount of GHO to be burned
   */
  function burn(uint256 amount) external;

  /**
   * @notice Returns the address of the GHO token
   * @return The address of GHO token contract
   */
  function GHO_TOKEN() external view returns (address);
}
