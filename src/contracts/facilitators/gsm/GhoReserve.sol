// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IGhoReserve} from './interfaces/IGhoReserve.sol';

/**
 * @title GhoReserve
 * @author Aave/TokenLogic
 * @notice GHO Remote Reserve. It provides withdraw/repay facilities to a GHO Stability Module in order to provide GHO liquidity on a remote chain.
 * @dev To be covered by a proxy contract.
 */
contract GhoReserve is IGhoReserve, Ownable, VersionedInitializable {
  /// @inheritdoc IGhoReserve
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
   * @notice GhoReserve initializer
   * @param admin The address of the default admin role
   */
  function initialize(address admin) external initializer {
    require(admin != address(0), 'ZERO_ADDRESS_NOT_VALID');
    _transferOwnership(admin);
  }

  /// @inheritdoc IGhoReserve
  function withdrawGho(uint256 amount) external {
    GhoCapacity memory callerInfo = _ghoCapacity[msg.sender];
    require(callerInfo.capacity >= callerInfo.withdrawn + amount, 'CAPACITY_REACHED');

    _ghoCapacity[msg.sender].withdrawn += uint128(amount);
    IERC20(GHO_TOKEN).transfer(msg.sender, amount);
  }

  /// @inheritdoc IGhoReserve
  function returnGho(uint256 amount) external {
    _ghoCapacity[msg.sender].withdrawn -= uint128(amount);
    IERC20(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
  }

  /// @inheritdoc IGhoReserve
  function rescueToken(address token, address to, uint256 amount) external onlyOwner {
    IERC20(GHO_TOKEN).transfer(to, amount);
    emit ERC20TokenTransfered(token, to, amount);
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
