// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';

import {ITypeAndVersion} from './ITypeAndVersion.sol';
import {IBurnMintERC20} from './IBurnMintERC20.sol';

import {UpgradeableTokenPool} from './UpgradeableTokenPool.sol';
import {UpgradeableBurnMintTokenPoolAbstract} from './UpgradeableBurnMintTokenPoolAbstract.sol';

import {IRouter} from './IRouter.sol';

/// @title UpgradeableBurnMintTokenPool
/// @author Aave Labs
/// @notice Upgradeable version of Chainlink's CCIP BurnMintTokenPool
/// @dev Contract adaptations:
/// - Implementation of Initializable to allow upgrades
/// - Move of allowlist and router definition to initialization stage
contract UpgradeableBurnMintTokenPool is
  Initializable,
  UpgradeableBurnMintTokenPoolAbstract,
  ITypeAndVersion
{
  string public constant override typeAndVersion = 'BurnMintTokenPool 1.4.0';

  /// @dev Constructor
  /// @param token The bridgeable token that is managed by this pool.
  /// @param armProxy The address of the arm proxy
  /// @param allowlistEnabled True if pool is set to access-controlled mode, false otherwise
  constructor(
    address token,
    address armProxy,
    bool allowlistEnabled
  ) UpgradeableTokenPool(IBurnMintERC20(token), armProxy, allowlistEnabled) {}

  /// @dev Initializer
  /// @dev The address passed as `owner` must accept ownership after initialization.
  /// @dev The `allowlist` is only effective if pool is set to access-controlled mode
  /// @param owner The address of the owner
  /// @param allowlist A set of addresses allowed to trigger lockOrBurn as original senders
  /// @param router The address of the router
  function initialize(
    address owner,
    address[] memory allowlist,
    address router
  ) public virtual initializer {
    if (owner == address(0)) revert ZeroAddressNotAllowed();
    if (router == address(0)) revert ZeroAddressNotAllowed();
    _transferOwnership(owner);

    s_router = IRouter(router);

    // Pool can be set as permissioned or permissionless at deployment time only to save hot-path gas.
    if (i_allowlistEnabled) {
      _applyAllowListUpdates(new address[](0), allowlist);
    }
  }

  /// @inheritdoc UpgradeableBurnMintTokenPoolAbstract
  function _burn(uint256 amount) internal virtual override {
    IBurnMintERC20(address(i_token)).burn(amount);
  }
}
