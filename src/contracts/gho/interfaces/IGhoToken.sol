// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Burnable} from './IERC20Burnable.sol';
import {IERC20Mintable} from './IERC20Mintable.sol';

/**
 * @title IGhoToken
 * @author Aave
 */
interface IGhoToken is IERC20Burnable, IERC20Mintable, IERC20 {
  struct Bucket {
    uint128 maxCapacity;
    uint128 level;
  }

  struct Facilitator {
    Bucket bucket;
    string label;
  }

  /**
   * @dev Emitted when a new facilitator is added
   * @param facilitatorAddress The address of the new facilitator
   * @param label A human readable identifier for the facilitator
   * @param initialBucketCapacity The initial capacity of the facilitator's bucket
   */
  event FacilitatorAdded(
    address indexed facilitatorAddress,
    string indexed label,
    uint256 initialBucketCapacity
  );

  /**
   * @dev Emitted when a facilitator is removed
   * @param facilitatorAddress The address of the facilitator to be removed
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
  event BucketLevelChanged(address indexed facilitatorAddress, uint256 oldLevel, uint256 newLevel);

  /**
   * @notice Adds the facilitators passed as parameters to the facilitators list.
   * @dev The two arrays need to have the same length. Each position corresponds to a tuple (address, config)
   * @param facilitatorsAddresses The addresses of the facilitators to add
   * @param facilitatorsConfig The configuration for each facilitator
   */
  function addFacilitator(
    address[] memory facilitatorsAddresses,
    Facilitator[] memory facilitatorsConfig
  ) external;

  /**
   * @notice Removes the facilitators from the facilitators list.
   * @param facilitators The addresses of the facilitators to remove
   */
  function removeFacilitators(address[] calldata facilitators) external;

  /**
   * @notice Set the facilitator bucket capacity.
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
   * @notice Returns the facilitator bucket configuration
   * @param facilitator The address of the facilitator
   * @return The facilitator bucket configuration
   */
  function getFacilitatorBucket(address facilitator) external view returns (Bucket memory);

  /**
   * @notice Returns the list of the addresses of the active facilitator
   * @return The list of the facilitators addresses
   */
  function getFacilitatorsList() external view returns (address[] memory);
}
