// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BurnMintTokenPool} from '@ccip/src/v0.8/ccip/pools/BurnMintTokenPool.sol';
import {IRouter} from '@ccip/src/v0.8/ccip/interfaces/IRouter.sol';
import {IBurnMintERC20} from '@ccip/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';

/**
 * @title UpgradeableBurnMintTokenPool
 * @author Aave Labs
 * @notice Upgradeable version of Chainlink's CCIP BurnMintTokenPool
 * @dev Contract adaptations:
 * - Implements VersionedInitializable to allow upgrades
 * - Disable allowlist, so moving tokens is permissionless
 */
contract UpgradeableBurnMintTokenPool is VersionedInitializable, BurnMintTokenPool {
  /**
   * @dev Constructor
   * @dev Passing empty array as `allowlist`, as pool is not access-controlled
   * @dev The router must be initialized via `initialize` as it is mutable
   * @param token The bridgeable token that is managed by this pool.
   * @param armProxy The address of the arm proxy
   * @param router The address of the router
   */
  constructor(
    address token,
    address armProxy,
    address router
  ) BurnMintTokenPool(IBurnMintERC20(token), new address[](0), armProxy, router) {
    // Intentionally left bank
  }

  /**
   * @dev Initializer
   * @dev The address passed as `owner` must accept ownership after initialization.
   * @param owner The address of the owner
   * @param router The address of the router
   */
  function initialize(address owner, address router) public virtual initializer {
    if (owner == address(0)) revert ZeroAddressNotAllowed();
    if (router == address(0)) revert ZeroAddressNotAllowed();

    s_router = IRouter(router);
    _transferOwnership(owner);
  }

  /**
   * @notice Returns the revision number
   * @return The revision number
   */
  function REVISION() public pure virtual returns (uint256) {
    return 1;
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return REVISION();
  }
}
