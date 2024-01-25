pragma solidity ^0.8.0;

import {OracleSwapFreezer} from '../../../src/contracts/facilitators/gsm/swapFreezer/OracleSwapFreezer.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPriceOracle} from '@aave/core-v3/contracts/interfaces/IPriceOracle.sol';
//import {AutomationCompatibleInterface} from '../dependencies/chainlink/AutomationCompatibleInterface.sol';
import {IGsm} from '../../../src/contracts/facilitators/gsm/interfaces/IGsm.sol';

contract OracleSwapFreezerHarness is OracleSwapFreezer {
  constructor(
    IGsm gsm,
    address underlyingAsset,
    IPoolAddressesProvider addressProvider,
    uint128 freezeLowerBound,
    uint128 freezeUpperBound,
    uint128 unfreezeLowerBound,
    uint128 unfreezeUpperBound,
    bool allowUnfreeze
  )
    OracleSwapFreezer(
      gsm,
      underlyingAsset,
      addressProvider,
      freezeLowerBound,
      freezeUpperBound,
      unfreezeLowerBound,
      unfreezeUpperBound,
      allowUnfreeze
    )
  {}

  function validateBounds(
    uint128 freezeLowerBound,
    uint128 freezeUpperBound,
    uint128 unfreezeLowerBound,
    uint128 unfreezeUpperBound,
    bool allowUnfreeze
  ) external pure returns (bool) {
    return
      _validateBounds(
        freezeLowerBound,
        freezeUpperBound,
        unfreezeLowerBound,
        unfreezeUpperBound,
        allowUnfreeze
      );
  }

  function isActionAllowed(Action actionToExecute) external view returns (bool) {
    return _isActionAllowed(actionToExecute);
  }

  function getAction() external view returns (uint8) {
    Action res = _getAction();
    if (res == Action.NONE) return 0;
    if (res == Action.FREEZE) return 1;
    if (res == Action.UNFREEZE) return 2;
    return 3;
  }

  function isSeized() external view returns (bool) {
    return GSM.getIsSeized();
  }

  function isFreezeAllowed() external view returns (bool) {
    return _isActionAllowed(Action.FREEZE);
  }

  function isUnfreezeAllowed() external view returns (bool) {
    return _isActionAllowed(Action.UNFREEZE);
  }

  function isFrozen() external view returns (bool) {
    return GSM.getIsFrozen();
  }

  function getPrice() external view returns (uint256) {
    return IPriceOracle(ADDRESS_PROVIDER.getPriceOracle()).getAssetPrice(UNDERLYING_ASSET);
  }

  function hasRole() external view returns(bool) {
    return GSM.hasRole(GSM.SWAP_FREEZER_ROLE(), address(this));
  }
}
