// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IBurnableERC20} from './IBurnableERC20.sol';
import {IMintableERC20} from './IMintableERC20.sol';

/**
 * @dev Interface of a burnable erc-20 token
 */
interface IGhoToken is IBurnableERC20, IMintableERC20 {

  event FacilitatorAdded(
    address indexed facilitatorAddress,
    string indexed label,
    uint256 initialBucketCapacity
  );
  event FacilitatorRemoved(address indexed facilitatorAddress);

  event FacilitatorBucketCapacityUpdated(
    address indexed facilitatorAaddress,
    uint256 oldCapacity,
    uint256 newCapacity
  );

  event BucketLevelChanged(address indexed facilitatorAaddress, uint256 oldLevel, uint256 newLevel);
}
