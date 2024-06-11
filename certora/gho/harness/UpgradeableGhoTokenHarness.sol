pragma solidity ^0.8.0;

import {IGhoToken} from '../munged/contracts/gho/interfaces/IGhoToken.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {UpgradeableGhoToken} from '../munged/contracts/gho/UpgradeableGhoToken.sol';

contract UpgradeableGhoTokenHarness is UpgradeableGhoToken {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor() UpgradeableGhoToken() {}

  /**
   * @notice Returns the bucket capacity
   * @param facilitator The address of the facilitator
   * @return The facilitator bucket capacity
   */
  function getFacilitatorBucketCapacity(address facilitator) public view returns (uint256) {
    (uint256 bucketCapacity, ) = getFacilitatorBucket(facilitator);
    return bucketCapacity;
  }

  /**
   * @notice Returns the bucket level
   * @param facilitator The address of the facilitator
   * @return The facilitator bucket level
   */
  function getFacilitatorBucketLevel(address facilitator) public view returns (uint256) {
    (, uint256 bucketLevel) = getFacilitatorBucket(facilitator);
    return bucketLevel;
  }

  /**
   * @notice Returns the length of the facilitator list
   * @return The length of the facilitator list
   */
  function getFacilitatorsListLen() external view returns (uint256) {
    address[] memory flist = getFacilitatorsList();
    return flist.length;
  }

  /**
   * @notice Indicator of GhoToken mapping
   * @param addr An address of a facilitator
   * @return True of facilitator is in GhoToken mapping
   */
  function is_in_facilitator_mapping(address addr) external view returns (bool) {
    Facilitator memory facilitator = _facilitators[addr];
    return facilitator.isLabelNonempty; //TODO: remove workaround when CERT-977 is resolved
    //  return (bytes(facilitator.label).length > 0);
  }

  /**
   * @notice Indicator of AddressSet mapping
   * @param addr An address of a facilitator
   * @return True of facilitator is in AddressSet mapping
   */
  function is_in_facilitator_set_map(address addr) external view returns (bool) {
    return _facilitatorsList.contains(addr);
  }

  /**
   * @notice Indicator of AddressSet list
   * @param addr An address of a facilitator
   * @return True of facilitator is in AddressSet array
   */
  function is_in_facilitator_set_array(address addr) external view returns (bool) {
    address[] memory flist = getFacilitatorsList();
    for (uint256 i = 0; i < flist.length; ++i) {
      if (address(flist[i]) == addr) {
        return true;
      }
    }
    return false;
  }

  /**
   * @notice Converts address to bytes32
   * @param value Some address
   * @return b the value as bytes32
   */
  function to_bytes32(address value) external pure returns (bytes32 b) {
    b = bytes32(uint256(uint160(value)));
  }
}
