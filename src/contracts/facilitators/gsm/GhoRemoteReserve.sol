// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IGhoRemoteReserve} from './interfaces/IGhoRemoteReserve.sol';

/**
 * @title GhoRemoteReserve
 * @author Aave/TokenLogic
 * @notice GHO Remote Reserve. It provides withdraw/repay facilities to a GHO Stability Module in order to provide GHO liquidity on a remote chain.
 * @dev To be covered by a proxy contract.
 */
contract GhoRemoteReserve is IGhoRemoteReserve, Ownable, VersionedInitializable {
  /// @inheritdoc IGhoRemoteReserve
  address public immutable GHO_TOKEN;

  /// @dev Mapping to keep track of GHO withdrawn by an address and capacity
  mapping(address => GhoCapacity) private _ghoCapacity;

  /**
   * @dev Constructor
   * @param ghoAddress Address of GHO token on the remote chain
   */
  constructor(address ghoAddress) Ownable() {
    require(ghoAddress != address(0), 'INVALID_ZERO_ADDRESS');

    GHO_TOKEN = ghoAddress;
  }

  /**
   * @notice GhoRemoteReserve initializer
   * @param admin The address of the default admin role
   */
  function initialize(address admin) external initializer {
    require(admin != address(0), 'ZERO_ADDRESS_NOT_VALID');
    _transferOwnership(admin);
  }

  /// @inheritdoc IGhoRemoteReserve
  function withdrawGho(uint256 amount) external {
    GhoCapacity memory callerInfo = _ghoCapacity[msg.sender];
    require(callerInfo.capacity >= callerInfo.withdrawn + amount, 'CAPACITY_REACHED');

    _ghoCapacity[msg.sender].withdrawn += uint128(amount);
    IERC20(GHO_TOKEN).transfer(msg.sender, amount);
  }

  /// @inheritdoc IGhoRemoteReserve
  function returnGho(uint256 amount) external {
    _ghoCapacity[msg.sender].withdrawn -= uint128(amount);
    IERC20(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
  }

  function bridgeGho(uint256 amount) external {
    // Intentionally left bank
  }

  /// @inheritdoc IGhoRemoteReserve
  function setWithdrawerCapacity(address withdrawer, uint256 capacity) external onlyOwner {
    _ghoCapacity[withdrawer].capacity = uint128(capacity);

    emit WithdrawerCapacityUpdated(withdrawer, capacity);
  }

  /// @inheritdoc IGhoRemoteReserve
  function getWithdrawnGho(address withdrawer) external view returns (uint256) {
    return _ghoCapacity[withdrawer].withdrawn;
  }

  /// @inheritdoc IGhoRemoteReserve
  function getCapacity(address withdrawer) external view returns (uint256) {
    return _ghoCapacity[withdrawer].capacity;
  }

  /// @inheritdoc IGhoRemoteReserve
  function GHO_REMOTE_RESERVE_REVISION() public pure virtual override returns (uint256) {
    return 1;
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return GHO_REMOTE_RESERVE_REVISION();
  }
}
