// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IGhoReserve} from './interfaces/IGhoReserve.sol';

/**
 * @title GhoReserve
 * @author Aave/TokenLogic
 * @notice It allows approved entities to withdraw and return GHO funds, with a defined maximum withdrawal capacity per entity.
 * @dev To be covered by a proxy contract.
 */
contract GhoReserve is Ownable, VersionedInitializable, IGhoReserve {
  /// @inheritdoc IGhoReserve
  address public immutable GHO_TOKEN;

  /// Map of entities and their assigned capacity and amount of GHO used
  mapping(address => GhoUsage) private _ghoUsage;

  /**
   * @dev Constructor
   * @param initialOwner The address of the owner
   * @param ghoAddress The address of the GHO token on the remote chain
   */
  constructor(address initialOwner, address ghoAddress) Ownable() {
    require(initialOwner != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(ghoAddress != address(0), 'ZERO_ADDRESS_NOT_VALID');

    _transferOwnership(initialOwner);
    GHO_TOKEN = ghoAddress;
  }

  /**
   * @dev Initializer
   * @param newOwner The address of the new owner
   */
  function initialize(address newOwner) external initializer {
    require(newOwner != address(0), 'ZERO_ADDRESS_NOT_VALID');
    _transferOwnership(newOwner);
  }

  /// @inheritdoc IGhoReserve
  function use(uint256 amount) external {
    GhoUsage storage entity = _ghoUsage[msg.sender];
    require(entity.limit >= entity.used + amount, 'LIMIT_REACHED');

    entity.used += uint128(amount);
    IERC20(GHO_TOKEN).transfer(msg.sender, amount);
    emit GhoUsed(msg.sender, amount);
  }

  /// @inheritdoc IGhoReserve
  function restore(uint256 amount) external {
    _ghoUsage[msg.sender].used -= uint128(amount);
    IERC20(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
    emit GhoRestored(msg.sender, amount);
  }

  /// @inheritdoc IGhoReserve
  function transfer(address to, uint256 amount) external onlyOwner {
    IERC20(GHO_TOKEN).transfer(to, amount);
    emit GhoTransferred(to, amount);
  }

  /// @inheritdoc IGhoReserve
  function setLimit(address entity, uint256 limit) external onlyOwner {
    _ghoUsage[entity].limit = uint128(limit);

    emit GhoLimitUpdated(entity, limit);
  }

  /// @inheritdoc IGhoReserve
  function getUsed(address entity) external view returns (uint256) {
    return _ghoUsage[entity].used;
  }

  /// @inheritdoc IGhoReserve
  function getUsage(address entity) external view returns (uint256, uint256) {
    GhoUsage memory usage = _ghoUsage[entity];
    return (usage.limit, usage.used);
  }

  /// @inheritdoc IGhoReserve
  function getLimit(address entity) external view returns (uint256) {
    return _ghoUsage[entity].limit;
  }

  /// @inheritdoc IGhoReserve
  function GHO_REMOTE_RESERVE_REVISION() public pure virtual override returns (uint256) {
    return 1;
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return GHO_REMOTE_RESERVE_REVISION();
  }
}
