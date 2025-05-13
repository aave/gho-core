// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IGhoReserve} from './interfaces/IGhoReserve.sol';

/**
 * @title GhoReserve
 * @author Aave/TokenLogic
 * @notice GHO Remote Reserve. It provides withdraw/return facilities to approved contracts. Maximum withdraw capacity
 * is specified per approved contract.
 * @dev To be covered by a proxy contract.
 */
contract GhoReserve is Ownable, VersionedInitializable, IGhoReserve {
  /// @inheritdoc IGhoReserve
  address public immutable GHO_TOKEN;

  /// @dev Mapping to keep track of GHO withdrawn by an address and capacity
  mapping(address => GhoCapacity) private _ghoCapacity;

  /**
   * @dev Constructor
   * @param initialOwner Address of the initial owner of the contract
   * @param ghoAddress Address of GHO token on the remote chain
   */
  constructor(address initialOwner, address ghoAddress) Ownable() {
    require(initialOwner != address(0), 'ZERO_ADDRESS_NOT_VALID');
    require(ghoAddress != address(0), 'ZERO_ADDRESS_NOT_VALID');

    _transferOwnership(initialOwner);

    GHO_TOKEN = ghoAddress;
  }

  /**
   * @dev Initializer
   * @param newOwner The address of the owner
   */
  function initialize(address newOwner) external initializer {
    require(newOwner != address(0), 'ZERO_ADDRESS_NOT_VALID');
    _transferOwnership(newOwner);
  }

  /// @inheritdoc IGhoReserve
  function useGho(uint256 amount) external {
    GhoCapacity memory callerInfo = _ghoCapacity[msg.sender];
    require(callerInfo.capacity >= callerInfo.withdrawn + amount, 'CAPACITY_REACHED');

    _ghoCapacity[msg.sender].withdrawn += uint128(amount);
    IERC20(GHO_TOKEN).transfer(msg.sender, amount);
  }

  /// @inheritdoc IGhoReserve
  function restoreGho(uint256 amount) external {
    _ghoCapacity[msg.sender].withdrawn -= uint128(amount);
    IERC20(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
  }

  /// @inheritdoc IGhoReserve
  function transferGho(address to, uint256 amount) external onlyOwner {
    IERC20(GHO_TOKEN).transfer(to, amount);
    emit GhoTokenTransfered(to, amount);
  }

  /// @inheritdoc IGhoReserve
  function setWithdrawerCapacity(address withdrawer, uint256 capacity) external onlyOwner {
    _ghoCapacity[withdrawer].capacity = uint128(capacity);

    emit WithdrawerCapacityUpdated(withdrawer, capacity);
  }

  /// @inheritdoc IGhoReserve
  function getWithdrawnGho(address withdrawer) external view returns (uint256) {
    return _ghoCapacity[withdrawer].withdrawn;
  }

  /// @inheritdoc IGhoReserve
  function getAvailableCapacity(address withdrawer) external view returns (uint256) {
    GhoCapacity memory capacity = _ghoCapacity[withdrawer];
    return capacity.capacity - capacity.withdrawn;
  }

  /// @inheritdoc IGhoReserve
  function getCapacity(address withdrawer) external view returns (uint256) {
    return _ghoCapacity[withdrawer].capacity;
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
