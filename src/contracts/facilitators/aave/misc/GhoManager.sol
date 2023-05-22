// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPoolConfigurator} from '@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {GhoInterestRateStrategy} from '../interestStrategy/GhoInterestRateStrategy.sol';
import {IGhoToken} from '../../../gho/interfaces/IGhoToken.sol';

/**
 * @title GhoSteward
 * @author Aave
 * @notice Helper contract for managing key risk parameters of the GHO reserve within the Aave Facilitator
 * @dev This contract must be granted `PoolAdmin` in the Aave V3 Ethereum Pool and `BucketManager` in GHO Token
 */
contract GhoManager is Ownable {
  address public immutable POOL_ADDRESSES_PROVIDER;
  address public immutable GHO_TOKEN;

  /**
   * @dev Constructor
   * @param addressesProvider The address of the PoolAddressesProvider of Aave V3 Ethereum Pool
   * @param ghoToken The address of the GhoToken
   */
  constructor(address addressesProvider, address ghoToken) {
    require(addressesProvider != address(0), 'INVALID_ADDRESSES_PROVIDER');
    require(ghoToken != address(0), 'INVALID_GHO_TOKEN');
    POOL_ADDRESSES_PROVIDER = addressesProvider;
    GHO_TOKEN = ghoToken;
  }

  /**
   * @notice Updates the ReserveInterestRateStrategy of GHO reserve
   * @param newRateStrategyAddress The address of new RateStrategyAddress contract
   */
  function setReserveInterestRateStrategyAddress(
    address newRateStrategyAddress
  ) external onlyOwner {
    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setReserveInterestRateStrategyAddress(GHO_TOKEN, newRateStrategyAddress);
  }

  /**
   * @notice Updates the Variable Borrow rate of GHO
   * @param newVariableBorrowRate The new variable borrow rate (expressed in ray)
   */
  function setReserveVariableBorrowRate(uint256 newVariableBorrowRate) external onlyOwner {
    GhoInterestRateStrategy newRateStrategy = new GhoInterestRateStrategy(newVariableBorrowRate);
    IPoolConfigurator(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPoolConfigurator())
      .setReserveInterestRateStrategyAddress(GHO_TOKEN, address(newRateStrategy));
  }

  /**
   * @notice Updates the Bucket Capacity of the Aave V3 Ethereum Pool Facilitator
   * @param newBucketCapacity The new bucket capacity of the facilitator
   */
  function setFacilitatorBucketCapacity(uint128 newBucketCapacity) external onlyOwner {
    DataTypes.ReserveData memory ghoReserveData = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getReserveData(GHO_TOKEN);
    require(ghoReserveData.aTokenAddress != address(0), 'GHO_ATOKEN_NOT_FOUND');
    IGhoToken(GHO_TOKEN).setFacilitatorBucketCapacity(
      ghoReserveData.aTokenAddress,
      newBucketCapacity
    );
  }
}
