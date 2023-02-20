// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Burnable} from './IERC20Burnable.sol';
import {IERC20Mintable} from './IERC20Mintable.sol';

/**
 * @title IGhoToken
 * @author Aave
 */
interface IGhoToken is IERC20Burnable, IERC20Mintable, IERC20 {
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
   * @notice Add the facilitator passed with the parameters to the facilitators list.
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
   * @param facilitatorAddress The address of the facilitator to remove
   */
  function removeFacilitator(address facilitatorAddress) external;

  /**
   * @notice Set the bucket capacity of the facilitator.
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
