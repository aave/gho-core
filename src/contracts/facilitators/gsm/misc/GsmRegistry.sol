// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IGsmRegistry} from './IGsmRegistry.sol';

/**
 * @title GsmRegistry
 * @author Aave
 * @notice Main registry of GSM contracts.
 */
contract GsmRegistry is Ownable, IGsmRegistry {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _gsmList;

  /**
   * @dev Constructor
   * @param newOwner The address of the contract owner
   */
  constructor(address newOwner) {
    require(newOwner != address(0), 'ZERO_ADDRESS_NOT_VALID');
    _transferOwnership(newOwner);
  }

  /// @inheritdoc IGsmRegistry
  function addGsm(address gsmAddress) external onlyOwner {
    require(gsmAddress != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(_gsmList.add(gsmAddress), 'GSM_ALREADY_ADDED');

    emit GsmAdded(gsmAddress);
  }

  /// @inheritdoc IGsmRegistry
  function removeGsm(address gsmAddress) external onlyOwner {
    require(gsmAddress != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(_gsmList.remove(gsmAddress), 'NONEXISTENT_GSM');

    emit GsmRemoved(gsmAddress);
  }

  /// @inheritdoc IGsmRegistry
  function getGsmList() external view returns (address[] memory) {
    return _gsmList.values();
  }

  /// @inheritdoc IGsmRegistry
  function getGsmListLength() external view returns (uint256) {
    return _gsmList.length();
  }

  /// @inheritdoc IGsmRegistry
  function getGsmAtIndex(uint256 index) external view returns (address) {
    require(index < _gsmList.length(), 'INVALID_INDEX');
    return _gsmList.at(index);
  }
}
