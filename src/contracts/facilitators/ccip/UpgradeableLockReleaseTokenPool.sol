// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LockReleaseTokenPool} from '@ccip/src/v0.8/ccip/pools/LockReleaseTokenPool.sol';
import {IRouter} from '@ccip/src/v0.8/ccip/interfaces/IRouter.sol';
import {IERC20} from '@ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';

/**
 * @title UpgradeableLockReleaseTokenPool
 * @author Aave Labs
 * @notice Upgradeable version of Chainlink's CCIP LockReleaseTokenPool
 * @dev Contract adaptations:
 * - Implements VersionedInitializable to allow upgrades
 * - Disable allowlist, so moving tokens is permissionless
 */
contract UpgradeableLockReleaseTokenPool is VersionedInitializable, LockReleaseTokenPool {
  uint256 public constant REVISION = 1;

  /**
   * @dev Constructor
   * @dev Passing empty array as `allowlist`, as pool is not access-controlled
   * @dev The router must be initialized via `initialize` as it is mutable
   * @param token The bridgeable token that is managed by this pool.
   * @param armProxy The address of the arm proxy
   * @param acceptLiquidity True if the pool accepts liquidity, false otherwise
   * @param router The address of the router
   */
  constructor(
    address token,
    address armProxy,
    bool acceptLiquidity,
    address router
  ) LockReleaseTokenPool(IERC20(token), new address[](0), armProxy, acceptLiquidity, router) {
    // Intentionally left bank
  }

  /**
   * @dev Initializer
   * @param owner The address of the owner
   * @param router The address of the router
   */
  function initialize(address owner, address router) public virtual initializer {
    if (owner == address(0)) revert ZeroAddressNotAllowed();
    if (router == address(0)) revert ZeroAddressNotAllowed();

    s_router = IRouter(router);
    _transferOwnership(owner);
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return REVISION;
  }
}
