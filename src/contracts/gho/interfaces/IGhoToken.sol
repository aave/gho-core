// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';

/**
 * @title IGhoToken
 * @author Aave
 */
interface IGhoToken is IERC20, IAccessControl {
  struct Facilitator {
    uint128 bucketCapacity;
    uint128 bucketLevel;
    string label;
  }

  /**
   * @dev Emitted when a new facilitator is added
   * @param facilitatorAddress The address of the new facilitator
   * @param label A hashed human readable identifier for the facilitator
   * @param bucketCapacity The initial capacity of the facilitator's bucket
   */
  event FacilitatorAdded(
    address indexed facilitatorAddress,
    bytes32 indexed label,
    uint256 bucketCapacity
  );

  /**
   * @dev Emitted when a facilitator is removed
   * @param facilitatorAddress The address of the removed facilitator
   */
  event FacilitatorRemoved(address indexed facilitatorAddress);

  /**
   * @dev Emitted when the bucket capacity of a facilitator is updated
   * @param facilitatorAddress The address of the facilitator whose bucket capacity is being changed
   * @param oldCapacity The old capacity of the bucket
   * @param newCapacity The new capacity of the bucket
   */
  event FacilitatorBucketCapacityUpdated(
    address indexed facilitatorAddress,
    uint256 oldCapacity,
    uint256 newCapacity
  );

  /**
   * @dev Emitted when the bucket level changed
   * @param facilitatorAddress The address of the facilitator whose bucket level is being changed
   * @param oldLevel The old level of the bucket
   * @param newLevel The new level of the bucket
   */
  event FacilitatorBucketLevelUpdated(
    address indexed facilitatorAddress,
    uint256 oldLevel,
    uint256 newLevel
  );

  /**
   * @notice Returns the identifier of the Facilitator Manager Role
   * @return The bytes32 id hash of the FacilitatorManager role
   */
  function FACILITATOR_MANAGER_ROLE() external pure returns (bytes32);

  /**
   * @notice Returns the identifier of the Bucket Manager Role
   * @return The bytes32 id hash of the BucketManager role
   */
  function BUCKET_MANAGER_ROLE() external pure returns (bytes32);

  /**
   * @notice Mints the requested amount of tokens to the account address.
   * @dev Only facilitators with enough bucket capacity available can mint.
   * @dev The bucket level is increased upon minting.
   * @param account The address receiving the GHO tokens
   * @param amount The amount to mint
   */
  function mint(address account, uint256 amount) external;

  /**
   * @notice Burns the requested amount of tokens from the account address.
   * @dev Only active facilitators (bucket level > 0) can burn.
   * @dev The bucket level is decreased upon burning.
   * @param amount The amount to burn
   */
  function burn(uint256 amount) external;

  /**
   * @notice Add the facilitator passed with the parameters to the facilitators list.
   * @dev Only accounts with `FACILITATOR_MANAGER_ROLE` role can call this function
   * @param facilitatorAddress The address of the facilitator to add
   * @param facilitatorLabel A human readable identifier for the facilitator
   * @param bucketCapacity The upward limit of GHO can be minted by the facilitator
   */
  function addFacilitator(
    address facilitatorAddress,
    string calldata facilitatorLabel,
    uint128 bucketCapacity
  ) external;

  /**
   * @notice Remove the facilitator from the facilitators list.
   * @dev Only accounts with `FACILITATOR_MANAGER_ROLE` role can call this function
   * @param facilitatorAddress The address of the facilitator to remove
   */
  function removeFacilitator(address facilitatorAddress) external;

  /**
   * @notice Set the bucket capacity of the facilitator.
   * @dev Only accounts with `BUCKET_MANAGER_ROLE` role can call this function
   * @param facilitator The address of the facilitator
   * @param newCapacity The new capacity of the bucket
   */
  function setFacilitatorBucketCapacity(address facilitator, uint128 newCapacity) external;

  /**
   * @notice Returns the facilitator data
   * @param facilitator The address of the facilitator
   * @return The facilitator configuration
   */
  function getFacilitator(address facilitator) external view returns (Facilitator memory);

  /**
   * @notice Returns the bucket configuration of the facilitator
   * @param facilitator The address of the facilitator
   * @return The capacity of the facilitator's bucket
   * @return The level of the facilitator's bucket
   */
  function getFacilitatorBucket(address facilitator) external view returns (uint256, uint256);

  /**
   * @notice Returns the list of the addresses of the active facilitator
   * @return The list of the facilitators addresses
   */
  function getFacilitatorsList() external view returns (address[] memory);
}
