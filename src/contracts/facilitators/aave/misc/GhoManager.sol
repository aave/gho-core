// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {PoolConfigurator} from '@aave/core-v3/contracts/protocol/pool/PoolConfigurator.sol';

// Gho Contracts
import {GhoVariableDebtToken} from 'src/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';

/**
 * @title GhoManager
 * @author Aave
 * @notice GhoManager contract for setting Gho interest rate strategy, discount rate strategy, and discount lock period
 */
contract GhoManager {
  // The Access Control List manager contract
  IACLManager private immutable ACL_MANAGER;

  /**
   * @dev Only risk or pool admin can call functions marked by this modifier.
   */
  modifier onlyGhoManager() {
    require(
      ACL_MANAGER.isRiskAdmin(msg.sender) || ACL_MANAGER.isPoolAdmin(msg.sender),
      Errors.CALLER_NOT_RISK_OR_POOL_ADMIN
    );
    _;
  }

  constructor(address addressesProvider) {
    ACL_MANAGER = IACLManager(IPoolAddressesProvider(addressesProvider).getACLManager());
  }

  /**
   * @notice Updates the Discount Rate Strategy
   * @param _ghoVariableDebtToken The address of GhoVariableDebtToken contract
   * @param newDiscountRateStrategy The address of DiscountRateStrategy contract
   */
  function updateDiscountRateStrategy(
    GhoVariableDebtToken _ghoVariableDebtToken,
    address newDiscountRateStrategy
  ) external onlyGhoManager {
    _ghoVariableDebtToken.updateDiscountRateStrategy(newDiscountRateStrategy);
  }

  /**
   * @notice Updates the Discount Lock Period
   * @param _ghoVariableDebtToken The address of GhoVariableDebtToken contract
   * @param newLockPeriod The new discount lock period (in seconds)
   */
  function updateDiscountLockPeriod(
    GhoVariableDebtToken _ghoVariableDebtToken,
    uint256 newLockPeriod
  ) external onlyGhoManager {
    _ghoVariableDebtToken.updateDiscountLockPeriod(newLockPeriod);
  }

  /**
   * @notice Updates the ReserveInterestRateStrategy for Gho
   * @param _poolConfigurator The address of PoolConfigurator contract
   * @param asset The address of the GHO deployed contract
   * @param newRateStrategyAddress The address of new RateStrategyAddress contract
   */
  function setReserveInterestRateStrategyAddress(
    PoolConfigurator _poolConfigurator,
    address asset,
    address newRateStrategyAddress
  ) external onlyGhoManager {
    _poolConfigurator.setReserveInterestRateStrategyAddress(asset, newRateStrategyAddress);
  }
}
