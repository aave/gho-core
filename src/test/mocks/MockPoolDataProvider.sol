// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IPoolAddressesProvider} from 'aave-address-book/AaveV3.sol';
import {IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';

contract MockPoolDataProvider is IPoolDataProvider {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  IPoolAddressesProvider public immutable POOL_ADDRESSES_PROVIDER;
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) {
    return POOL_ADDRESSES_PROVIDER;
  }

  constructor(address addressesProvider) {
    POOL_ADDRESSES_PROVIDER = IPoolAddressesProvider(addressesProvider);
  }

  function getInterestRateStrategyAddress(address asset) external view returns (address) {
    DataTypes.ReserveData memory reserveData = IPool(
      IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER).getPool()
    ).getReserveData(asset);
    return reserveData.interestRateStrategyAddress;
  }

  function getATokenTotalSupply(address asset) external view returns (uint256) {
    return 0;
  }

  function getAllATokens() external view returns (TokenData[] memory) {
    return new TokenData[](0);
  }

  function getAllReservesTokens() external view returns (TokenData[] memory) {
    return new TokenData[](0);
  }

  function getDebtCeiling(address asset) external view returns (uint256) {
    return 0;
  }

  function getDebtCeilingDecimals() external pure returns (uint256) {
    return 0;
  }

  function getFlashLoanEnabled(address asset) external view returns (bool) {
    return false;
  }

  function getLiquidationProtocolFee(address asset) external view returns (uint256) {
    return 0;
  }

  function getPaused(address asset) external view returns (bool isPaused) {
    return false;
  }
  function getReserveCaps(
    address asset
  ) external view returns (uint256 borrowCap, uint256 supplyCap) {
    return (0, 0);
  }

  function getReserveConfigurationData(
    address asset
  )
    external
    view
    returns (
      uint256 decimals,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      uint256 reserveFactor,
      bool usageAsCollateralEnabled,
      bool borrowingEnabled,
      bool stableBorrowRateEnabled,
      bool isActive,
      bool isFrozen
    )
  {
    return (0, 0, 0, 0, 0, false, false, false, false, false);
  }

  function getReserveData(
    address asset
  )
    external
    view
    returns (
      uint256 unbacked,
      uint256 accruedToTreasuryScaled,
      uint256 totalAToken,
      uint256 totalStableDebt,
      uint256 totalVariableDebt,
      uint256 liquidityRate,
      uint256 variableBorrowRate,
      uint256 stableBorrowRate,
      uint256 averageStableBorrowRate,
      uint256 liquidityIndex,
      uint256 variableBorrowIndex,
      uint40 lastUpdateTimestamp
    )
  {
    return (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  }

  function getReserveEModeCategory(address asset) external view returns (uint256) {
    return 0;
  }

  function getReserveTokensAddresses(
    address asset
  )
    external
    view
    returns (
      address aTokenAddress,
      address stableDebtTokenAddress,
      address variableDebtTokenAddress
    )
  {
    return (address(0), address(0), address(0));
  }

  function getSiloedBorrowing(address asset) external view returns (bool) {
    return false;
  }

  function getTotalDebt(address asset) external view returns (uint256) {
    return 0;
  }

  function getUnbackedMintCap(address asset) external view returns (uint256) {
    return 0;
  }

  function getUserReserveData(
    address asset,
    address user
  )
    external
    view
    returns (
      uint256 currentATokenBalance,
      uint256 currentStableDebt,
      uint256 currentVariableDebt,
      uint256 principalStableDebt,
      uint256 scaledVariableDebt,
      uint256 stableBorrowRate,
      uint256 liquidityRate,
      uint40 stableRateLastUpdated,
      bool usageAsCollateralEnabled
    )
  {
    return (0, 0, 0, 0, 0, 0, 0, 0, false);
  }
}
