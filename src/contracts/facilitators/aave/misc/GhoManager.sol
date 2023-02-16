// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {IGhoVariableDebtToken} from 'src/contracts/facilitators/aave/tokens/interfaces/IGhoVariableDebtToken.sol';

/**
 * @title GhoManager
 * @author Aave
 * @notice Helper contract for managing key risk parameters of the GHO reserve within the Aave Facilitator
 * @dev This contract is intended to be granted as PoolAdmin
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
   * @param ghoVariableDebtToken The address of GhoVariableDebtToken contract
   * @param newDiscountRateStrategy The address of DiscountRateStrategy contract
   */
  function updateDiscountRateStrategy(
    address ghoVariableDebtToken,
    address newDiscountRateStrategy
  ) external onlyOwner {
    IGhoVariableDebtToken(ghoVariableDebtToken).updateDiscountRateStrategy(newDiscountRateStrategy);
  }

  /**
   * @notice Updates the Discount Lock Period
   * @param ghoVariableDebtToken The address of GhoVariableDebtToken contract
   * @param newLockPeriod The new discount lock period (in seconds)
   */
  function updateDiscountLockPeriod(
    address ghoVariableDebtToken,
    uint256 newLockPeriod
  ) external onlyOwner {
    IGhoVariableDebtToken(ghoVariableDebtToken).updateDiscountLockPeriod(newLockPeriod);
  }

  /**
   * @notice Updates the ReserveInterestRateStrategy
   * @param poolConfigurator The address of PoolConfigurator contract
   * @param asset The address of the GHO deployed contract
   * @param newRateStrategyAddress The address of new RateStrategyAddress contract
   */
  function setReserveInterestRateStrategyAddress(
    address poolConfigurator,
    address asset,
    address newRateStrategyAddress
  ) external onlyOwner {
    IPoolConfigurator(poolConfigurator).setReserveInterestRateStrategyAddress(
      asset,
      newRateStrategyAddress
    );
  }
}
