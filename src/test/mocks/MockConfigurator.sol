// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {IDefaultInterestRateStrategyV2} from 'aave-v3-origin/core/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';

contract MockConfigurator {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  IPool internal _pool;

  event ReserveInterestRateStrategyChanged(
    address indexed asset,
    address oldStrategy,
    address newStrategy
  );

  event BorrowCapChanged(address indexed asset, uint256 oldBorrowCap, uint256 newBorrowCap);

  event ReserveInterestRateDataChanged(address indexed asset, address indexed strategy, bytes data);

  constructor(IPool pool) {
    _pool = pool;
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  function setReserveInterestRateStrategyAddress(
    address asset,
    address newRateStrategyAddress
  ) external {
    DataTypes.ReserveData memory reserve = _pool.getReserveData(asset);
    address oldRateStrategyAddress = reserve.interestRateStrategyAddress;
    _pool.setReserveInterestRateStrategyAddress(asset, newRateStrategyAddress);
    emit ReserveInterestRateStrategyChanged(asset, oldRateStrategyAddress, newRateStrategyAddress);
  }

  function setReserveInterestRateStrategyAddress(
    address asset,
    address rateStrategyAddress,
    bytes calldata rateData
  ) external {
    DataTypes.ReserveData memory reserve = _pool.getReserveData(asset);
    _updateInterestRateStrategy(asset, reserve, rateStrategyAddress, rateData);
  }

  function setReserveInterestRateData(
    address asset,
    bytes calldata rateData
  ) external {
    DataTypes.ReserveData memory reserve = _pool.getReserveData(asset);
    _updateInterestRateStrategy(asset, reserve, reserve.interestRateStrategyAddress, rateData);
  }

  function setBorrowCap(address asset, uint256 newBorrowCap) external {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    uint256 oldBorrowCap = currentConfig.getBorrowCap();
    currentConfig.setBorrowCap(newBorrowCap);
    _pool.setConfiguration(asset, currentConfig);
    emit BorrowCapChanged(asset, oldBorrowCap, newBorrowCap);
  }

  function _updateInterestRateStrategy(
    address asset,
    DataTypes.ReserveData memory reserve,
    address newRateStrategyAddress,
    bytes calldata rateData
  ) internal {
    address oldRateStrategyAddress = reserve.interestRateStrategyAddress;

    IDefaultInterestRateStrategyV2(newRateStrategyAddress).setInterestRateParams(asset, rateData);
    emit ReserveInterestRateDataChanged(asset, newRateStrategyAddress, rateData);

    if (oldRateStrategyAddress != newRateStrategyAddress) {
      _pool.setReserveInterestRateStrategyAddress(asset, newRateStrategyAddress);
      emit ReserveInterestRateStrategyChanged(
        asset,
        oldRateStrategyAddress,
        newRateStrategyAddress
      );
    }
  }
}
