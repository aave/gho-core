// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPriceOracle} from '@aave/core-v3/contracts/interfaces/IPriceOracle.sol';
import {AutomationCompatibleInterface} from '../dependencies/chainlink/AutomationCompatibleInterface.sol';
import {IGsm} from '../interfaces/IGsm.sol';

/**
 * @title OracleSwapFreezer
 * @author Aave
 * @notice Swap freezer that enacts the freeze action based on underlying oracle price, GSM's state and predefined price boundaries
 * @dev Chainlink Automation-compatible contract using Aave V3 Price Oracle, where prices are USD denominated with 8-decimal precision
 * @dev Freeze action is executable if GSM is not seized, not frozen and price is outside of the freeze bounds
 * @dev Unfreeze action is executable if GSM is not seized, frozen, unfreezing is allowed and price is inside the unfreeze bounds
 */
contract OracleSwapFreezer is AutomationCompatibleInterface {
  enum Action {
    NONE,
    FREEZE,
    UNFREEZE
  }

  IGsm public immutable GSM;
  address public immutable UNDERLYING_ASSET;
  IPoolAddressesProvider public immutable ADDRESS_PROVIDER;
  uint128 internal immutable _freezeLowerBound;
  uint128 internal immutable _freezeUpperBound;
  uint128 internal immutable _unfreezeLowerBound;
  uint128 internal immutable _unfreezeUpperBound;
  bool internal immutable _allowUnfreeze;

  /**
   * @dev Constructor
   * @dev Freeze/unfreeze bounds are specified in USD with 8-decimal precision, like Aave v3 Price Oracles
   * @dev Unfreeze boundaries are "contained" in freeze boundaries, where freezeLowerBound < unfreezeLowerBound and unfreezeUpperBound < freezeUpperBound
   * @dev All bound ranges are inclusive
   * @param gsm The GSM that this contract will trigger freezes/unfreezes on
   * @param underlyingAsset The address of the collateral asset
   * @param addressProvider The Aave Addresses Provider for looking up the Price Oracle
   * @param freezeLowerBound The lower price bound for freeze operations
   * @param freezeUpperBound The upper price bound for freeze operations
   * @param unfreezeLowerBound The lower price bound for unfreeze operations, must be 0 if unfreezing not allowed
   * @param unfreezeUpperBound The upper price bound for unfreeze operations, must be 0 if unfreezing not allowed
   * @param allowUnfreeze True if bounds verification should factor in the unfreeze boundary, false otherwise
   */
  constructor(
    IGsm gsm,
    address underlyingAsset,
    IPoolAddressesProvider addressProvider,
    uint128 freezeLowerBound,
    uint128 freezeUpperBound,
    uint128 unfreezeLowerBound,
    uint128 unfreezeUpperBound,
    bool allowUnfreeze
  ) {
    require(gsm.UNDERLYING_ASSET() == underlyingAsset, 'UNDERLYING_ASSET_MISMATCH');
    require(
      _validateBounds(
        freezeLowerBound,
        freezeUpperBound,
        unfreezeLowerBound,
        unfreezeUpperBound,
        allowUnfreeze
      ),
      'BOUNDS_NOT_VALID'
    );
    GSM = gsm;
    UNDERLYING_ASSET = underlyingAsset;
    ADDRESS_PROVIDER = addressProvider;
    _freezeLowerBound = freezeLowerBound;
    _freezeUpperBound = freezeUpperBound;
    _unfreezeLowerBound = unfreezeLowerBound;
    _unfreezeUpperBound = unfreezeUpperBound;
    _allowUnfreeze = allowUnfreeze;
  }

  /// @inheritdoc AutomationCompatibleInterface
  function performUpkeep(bytes calldata) external {
    Action action = _getAction();
    if (action == Action.FREEZE) {
      GSM.setSwapFreeze(true);
    } else if (action == Action.UNFREEZE) {
      GSM.setSwapFreeze(false);
    }
  }

  /// @inheritdoc AutomationCompatibleInterface
  function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
    return (_getAction() == Action.NONE ? false : true, '');
  }

  /**
   * @notice Returns whether or not the swap freezer can unfreeze a GSM
   * @return True if the freezer can unfreeze, false otherwise
   */
  function getCanUnfreeze() external view returns (bool) {
    return _allowUnfreeze;
  }

  /**
   * @notice Returns the bound used for freeze operations
   * @return The freeze lower bound (inclusive)
   * @return The freeze upper bound (inclusive)
   */
  function getFreezeBound() external view returns (uint128, uint128) {
    return (_freezeLowerBound, _freezeUpperBound);
  }

  /**
   * @notice Returns the bound used for unfreeze operations, or (0, 0) if unfreezing not allowed
   * @return The unfreeze lower bound (inclusive), or 0 if unfreezing not allowed
   * @return The unfreeze upper bound (inclusive), or 0 if unfreezing not allowed
   */
  function getUnfreezeBound() external view returns (uint128, uint128) {
    return (_unfreezeLowerBound, _unfreezeUpperBound);
  }

  /**
   * @notice Fetches price oracle data and checks whether a swap freeze or unfreeze action is required
   * @return The action to take (none, freeze, or unfreeze)
   */
  function _getAction() internal view returns (Action) {
    if (GSM.hasRole(GSM.SWAP_FREEZER_ROLE(), address(this))) {
      if (GSM.getIsSeized()) {
        return Action.NONE;
      } else if (!GSM.getIsFrozen()) {
        if (_isActionAllowed(Action.FREEZE)) {
          return Action.FREEZE;
        }
      } else if (_allowUnfreeze) {
        if (_isActionAllowed(Action.UNFREEZE)) {
          return Action.UNFREEZE;
        }
      }
    }
    return Action.NONE;
  }

  /**
   * @notice Checks whether the action is allowed, based on the action, oracle price and freeze/unfreeze bounds
   * @dev Freeze action is allowed if price is outside of the freeze bounds
   * @dev Unfreeze action is allowed if price is inside the unfreeze bounds
   * @param actionToExecute The requested action type to validate
   * @return True if conditions to execute the action passed are met, false otherwise
   */
  function _isActionAllowed(Action actionToExecute) internal view returns (bool) {
    uint256 oraclePrice = IPriceOracle(ADDRESS_PROVIDER.getPriceOracle()).getAssetPrice(
      UNDERLYING_ASSET
    );
    // Assume a 0 oracle price is invalid and no action should be taken based on that data
    if (oraclePrice == 0) {
      return false;
    } else if (actionToExecute == Action.FREEZE) {
      if (oraclePrice <= _freezeLowerBound || oraclePrice >= _freezeUpperBound) {
        return true;
      }
    } else if (actionToExecute == Action.UNFREEZE) {
      if (oraclePrice >= _unfreezeLowerBound && oraclePrice <= _unfreezeUpperBound) {
        return true;
      }
    }
    return false;
  }

  /**
   * @notice Verifies that the unfreeze bound and freeze bounds do not conflict, causing unexpected behaviour
   * @param freezeLowerBound The lower bound for freeze operations
   * @param freezeUpperBound The upper bound for freeze operations
   * @param unfreezeLowerBound The lower bound for unfreeze operations, must be 0 if unfreezing not allowed
   * @param unfreezeUpperBound The upper bound for unfreeze operations, must be 0 if unfreezing not allowed
   * @param allowUnfreeze True if bounds verification should factor in the unfreeze boundary, false otherwise
   * @return True if the bounds are valid and conflict-free, false otherwise
   */
  function _validateBounds(
    uint128 freezeLowerBound,
    uint128 freezeUpperBound,
    uint128 unfreezeLowerBound,
    uint128 unfreezeUpperBound,
    bool allowUnfreeze
  ) internal pure returns (bool) {
    if (freezeLowerBound >= freezeUpperBound) {
      return false;
    } else if (allowUnfreeze) {
      if (
        unfreezeLowerBound >= unfreezeUpperBound ||
        freezeLowerBound >= unfreezeLowerBound ||
        freezeUpperBound <= unfreezeUpperBound
      ) {
        return false;
      }
    } else {
      if (unfreezeLowerBound != 0 || unfreezeUpperBound != 0) {
        return false;
      }
    }
    return true;
  }
}
