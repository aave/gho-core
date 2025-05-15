// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGhoReserve {
  /**
   * Struct representing GSM's maximum allowed GHO usage and amount used
   * @param limit The maximum amount of GHO that can be used
   * @param used The current amount of GHO used
   */
  struct GhoUsage {
    uint128 limit;
    uint128 used;
  }

  /**
   * Transfers GHO to a specified address
   * @param to Address receiving GHO token
   * @param amount Amount of token to transfer
   */
  event GhoTokenTransfered(address to, uint256 amount);

  /**
   * @dev Emitted when the GHO limit for a given entity is updated
   * @param entity Address that can use GHO
   * @param limit Maximum limit
   */
  event EntityLimitUpdated(address indexed entity, uint256 limit);

  /**
   * @notice Returns the address of the GHO token
   * @return The address of GHO token contract
   */
  function GHO_TOKEN() external view returns (address);

  /**
   * @notice Accepts GHO to be repaied by caller
   * @param amount The amount of GHO to return
   */
  function restore(uint256 amount) external;

  /**
   * @notice Allows allowed caller to use GHO from reserve
   * @param amount The amount of GHO to use
   */
  function use(uint256 amount) external;

  /**
   * Rescues an ERC20 token by sending to a specified address
   * @param to Address receiving the GHO token
   * @param amount Amount of ERC20 token to transfer
   */
  function transfer(address to, uint256 amount) external;

  /**
   * Sets a given addresses' limit
   * @dev Only callable by the owner of the GhoReserve.
   * @param entity Address that can use GHO
   * @param limit Maximum amount of GHO that can be used
   */
  function setEntityLimit(address entity, uint256 limit) external;

  /**
   * Returns amount of GHO used by a specified address
   * @param entity Address of the contract that withdrew GHO from reserve
   */
  function getUsed(address entity) external view returns (uint256);

  /**
   * Returns limit of GHO and used amount for a given entity
   * @param entity Address of the contract that can use GHO from reserve
   * @return Limit of GHO that can be used
   * @return Used amount
   */
  function getUsage(address entity) external view returns (uint256, uint256);

  /**
   * Returns maximum amount of GHO that can be used by a specified address
   * @param entity Address of the contract that uses GHO from reserve
   */
  function getLimit(address entity) external view returns (uint256);

  /**
   * @notice Returns the GhoReserve revision number
   * @return The revision number
   */
  function GHO_REMOTE_RESERVE_REVISION() external pure returns (uint256);
}
