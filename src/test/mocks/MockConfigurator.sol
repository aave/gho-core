// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {DefaultReserveInterestRateStrategyV2} from '../../contracts/misc/deps/Dependencies.sol';
import {IDefaultInterestRateStrategyV2} from '../../contracts/misc/deps/Dependencies.sol';

contract MockConfigurator {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  IPool internal _pool;

  event ReserveInterestRateStrategyChanged(
    address indexed asset,
    address oldStrategy,
    address newStrategy
  );

  event BorrowCapChanged(address indexed asset, uint256 oldBorrowCap, uint256 newBorrowCap);

  event SupplyCapChanged(address indexed asset, uint256 oldSupplyCap, uint256 newSupplyCap);

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

  function setReserveInterestRateParams(
    address asset,
    IDefaultInterestRateStrategyV2.InterestRateData calldata rateParams
  ) external {
    DataTypes.ReserveData memory reserve = _pool.getReserveData(asset);
    address rateStrategyAddress = reserve.interestRateStrategyAddress;
    DefaultReserveInterestRateStrategyV2(rateStrategyAddress).setInterestRateParams(
      asset,
      rateParams
    );
  }

  function setBorrowCap(address asset, uint256 newBorrowCap) external {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    uint256 oldBorrowCap = currentConfig.getBorrowCap();
    currentConfig.setBorrowCap(newBorrowCap);
    _pool.setConfiguration(asset, currentConfig);
    emit BorrowCapChanged(asset, oldBorrowCap, newBorrowCap);
  }

  function setSupplyCap(address asset, uint256 newSupplyCap) external {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    uint256 oldSupplyCap = currentConfig.getSupplyCap();
    currentConfig.setSupplyCap(newSupplyCap);
    _pool.setConfiguration(asset, currentConfig);
    emit SupplyCapChanged(asset, oldSupplyCap, newSupplyCap);
  }
}
