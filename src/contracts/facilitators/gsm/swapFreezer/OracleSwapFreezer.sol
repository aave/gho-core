// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPriceOracle} from '@aave/core-v3/contracts/interfaces/IPriceOracle.sol';
import {AutomationCompatibleInterface} from '../dependencies/chainlink/AutomationCompatibleInterface.sol';
import {IGsm} from '../interfaces/IGsm.sol';

/**
 * @title OracleSwapFreezer
 * @author Aave
 * @notice Swap freezer that is ChainLink Automation-compatible, querying oracles to freeze/unfreeze
 * @dev This contract uses Aave v3 Price Oracles, where the oracle returns prices in USD with 8-decimal precision
 */
contract OracleSwapFreezer is AutomationCompatibleInterface {
  enum Action {
    NONE,
    FREEZE,
    UNFREEZE
  }

  struct Bound {
    uint128 lowerBound;
    uint128 upperBound;
  }

  IGsm public immutable GSM;
  address public immutable UNDERLYING_ASSET;
  IPoolAddressesProvider public immutable ADDRESS_PROVIDER;

  Bound internal _freezeBound;
  Bound internal _unfreezeBound;
  bool internal _allowUnfreeze;

  /**
   * @dev Constructor
   * @dev Freeze/unfreeze bounds are specified in USD with 8-decimal precision, like Aave v3 Price Oracles
   * @dev Unfreeze boundaries are "contained" in freeze boundaries, where freeze.lowerBound <= unfreeze.upperBound and freeze.upperBound <= unfreeze.upperBound
   * @dev All bound ranges are inclusive
   * @param gsm The GSM that this contract will trigger freezes/unfreezes on
   * @param underlyingAsset The address of the collateral asset
   * @param addressProvider The Aave Addresses Provider for looking up the Price Oracle
   * @param freezeBound The defined boundary where a "freeze" operation can be initiated
   * @param unfreezeBound The defined boundary where an "unfreeze" operation can be initiated; ignored if allowUnfreeze is false
   * @param allowUnfreeze True if bounds verification should factor in the unfreeze boundary, false otherwise
   */
  constructor(
    IGsm gsm,
    address underlyingAsset,
    IPoolAddressesProvider addressProvider,
    Bound memory freezeBound,
    Bound memory unfreezeBound,
    bool allowUnfreeze
  ) {
    require(gsm.UNDERLYING_ASSET() == underlyingAsset, 'UNDERLYING_ASSET_MISMATCH');
    require(_validateBounds(freezeBound, unfreezeBound, allowUnfreeze), 'BOUNDS_NOT_VALID');
    GSM = gsm;
    UNDERLYING_ASSET = underlyingAsset;
    ADDRESS_PROVIDER = addressProvider;
    _freezeBound = freezeBound;
    _unfreezeBound = unfreezeBound;
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
   * @return The freeze bound
   */
  function getFreezeBound() external view returns (Bound memory) {
    return _freezeBound;
  }

  /**
   * @notice Returns the bound used for unfreeze operations, or (0, 0) if unfreezing not allowed
   * @return The unfreeze bound, or (0, 0) if unfreezing not allowed
   */
  function getUnfreezeBound() external view returns (Bound memory) {
    return _allowUnfreeze ? _unfreezeBound : Bound(0, 0);
  }

  /**
   * @notice Fetches price oracle data and checks whether a swap freeze or unfreeze action is required
   * @return The action to take (none, freeze, or unfreeze)
   */
  function _getAction() internal view returns (Action) {
    if (!GSM.getIsFrozen()) {
      if (_isActionAllowed(Action.FREEZE)) {
        return Action.FREEZE;
      }
    } else if (_allowUnfreeze) {
      if (_isActionAllowed(Action.UNFREEZE)) {
        return Action.UNFREEZE;
      }
    }
    return Action.NONE;
  }

  /**
   * @notice Gets oracle price and verifies that it falls "outside" of the freeze bounds or "inside" the unfreeze bounds
   * @param actionToExecute The requested action type to validate
   * @return True if oracle price is within a boundary, enabling the requested action
   */
  function _isActionAllowed(Action actionToExecute) internal view returns (bool) {
    uint256 oraclePrice = IPriceOracle(ADDRESS_PROVIDER.getPriceOracle()).getAssetPrice(
      UNDERLYING_ASSET
    );
    if (oraclePrice == 0) {
      return false;
    } else if (actionToExecute == Action.FREEZE) {
      if (oraclePrice <= _freezeBound.lowerBound || oraclePrice >= _freezeBound.upperBound) {
        return true;
      }
    } else if (actionToExecute == Action.UNFREEZE) {
      if (oraclePrice >= _unfreezeBound.lowerBound && oraclePrice <= _unfreezeBound.upperBound) {
        return true;
      }
    }
    return false;
  }

  /**
   * @notice Verifies that the unfreeze bound and freeze bounds do not conflict, causing unexpected behaviour
   * @param freezeBound The defined boundary where a "freeze" operation can be initiated
   * @param unfreezeBound The defined boundary where an "unfreeze" operation can be initiated
   * @param allowUnfreeze True if bounds verification should factor in the unfreeze boundary, false otherwise
   * @return True if the bounds are valid and conflict-free, false otherwise
   */
  function _validateBounds(
    Bound memory freezeBound,
    Bound memory unfreezeBound,
    bool allowUnfreeze
  ) internal pure returns (bool) {
    if (freezeBound.lowerBound >= freezeBound.upperBound) {
      return false;
    } else if (allowUnfreeze) {
      if (
        unfreezeBound.lowerBound >= unfreezeBound.upperBound ||
        freezeBound.lowerBound >= unfreezeBound.lowerBound ||
        freezeBound.upperBound <= unfreezeBound.upperBound
      ) {
        return false;
      }
    }
    return true;
  }
}
