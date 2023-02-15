// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Aave Contracts
import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {IGhoVariableDebtToken} from 'src/contracts/facilitators/aave/tokens/interfaces/IGhoVariableDebtToken.sol';

// OZ Contracts
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

// Gho Contracts
import {GhoVariableDebtToken} from 'src/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';

/**
 * @title GhoManager
 * @author Aave
 * @notice GhoManager contract for setting Gho interest rate strategy, discount rate strategy, and discount lock period
 */
contract GhoManager is Ownable {
  /**
   * @dev Constructor.
   * @param owner The owner address of this contract
   */
  constructor(address owner) {
    transferOwnership(owner);
  }

  /**
   * @notice Updates the Discount Rate Strategy
   * @param _ghoVariableDebtToken The address of GhoVariableDebtToken contract
   * @param newDiscountRateStrategy The address of DiscountRateStrategy contract
   */
  function updateDiscountRateStrategy(
    address _ghoVariableDebtToken,
    address newDiscountRateStrategy
  ) external onlyOwner {
    IGhoVariableDebtToken(_ghoVariableDebtToken).updateDiscountRateStrategy(
      newDiscountRateStrategy
    );
  }

  /**
   * @notice Updates the Discount Lock Period
   * @param _ghoVariableDebtToken The address of GhoVariableDebtToken contract
   * @param newLockPeriod The new discount lock period (in seconds)
   */
  function updateDiscountLockPeriod(
    address _ghoVariableDebtToken,
    uint256 newLockPeriod
  ) external onlyOwner {
    IGhoVariableDebtToken(_ghoVariableDebtToken).updateDiscountLockPeriod(newLockPeriod);
  }

  /**
   * @notice Updates the ReserveInterestRateStrategy for Gho
   * @param _poolConfigurator The address of PoolConfigurator contract
   * @param asset The address of the GHO deployed contract
   * @param newRateStrategyAddress The address of new RateStrategyAddress contract
   */
  function setReserveInterestRateStrategyAddress(
    address _poolConfigurator,
    address asset,
    address newRateStrategyAddress
  ) external onlyOwner {
    IPoolConfigurator(_poolConfigurator).setReserveInterestRateStrategyAddress(
      asset,
      newRateStrategyAddress
    );
  }
}
