// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

// external dependencies
import {IAaveOracle} from '../interfaces/IAaveOracle.sol';
import {ILendingPool} from '../interfaces/ILendingPool.sol';
import {ILendingPoolAddressesProvider} from '../interfaces/ILendingPoolAddressesProvider.sol';
import {ILendingPoolConfigurator} from '../interfaces/ILendingPoolConfigurator.sol';

contract AaveV2MarketHelper {
  address public constant AAVE_ORACLE_ADDRESS = 0xA50ba011c48153De246E5192C8f9258A2ba79Ca9;
  address public constant LENDING_POOL_ADDRESS = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
  address public constant LENDING_POOL_ADDRESSES_PROVIDER_ADDRESS =
    0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
  address public constant LENDING_POOL_CONFIGURATOR = 0x311Bb771e4F8952E6Da169b425E7e92d6Ac45756;

  IAaveOracle aaveOracle = IAaveOracle(AAVE_ORACLE_ADDRESS);
  ILendingPool aavePool = ILendingPool(LENDING_POOL_ADDRESS);
}
