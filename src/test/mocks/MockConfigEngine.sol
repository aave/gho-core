// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {MockConfigurator} from './MockConfigurator.sol';
import {GhoInterestRateStrategy} from 'src/contracts/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {DefaultReserveInterestRateStrategyV2} from '../../contracts/misc/deps/Dependencies.sol';
import {IDefaultInterestRateStrategyV2} from '../../contracts/misc/deps/Dependencies.sol';

contract MockConfigEngine {
  address public immutable CONFIGURATOR;
  address public immutable PROVIDER;

  constructor(address configurator, address provider) {
    CONFIGURATOR = configurator;
    PROVIDER = provider;
  }

  struct InterestRateInputData {
    uint256 optimalUsageRatio;
    uint256 baseVariableBorrowRate;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
  }

  struct RateStrategyUpdate {
    address asset;
    InterestRateInputData params;
  }

  function updateRateStrategies(RateStrategyUpdate[] calldata updates) external {
    /*
    GhoInterestRateStrategy newRateStrategy = new GhoInterestRateStrategy(
      address(PROVIDER),
      updates[0].params.baseVariableBorrowRate
    );*/
    DefaultReserveInterestRateStrategyV2 newRateStrategy = new DefaultReserveInterestRateStrategyV2(
      address(PROVIDER)
    );

    MockConfigurator(CONFIGURATOR).setReserveInterestRateStrategyAddress(
      address(updates[0].asset),
      address(newRateStrategy)
    );

    MockConfigurator(CONFIGURATOR).setReserveInterestRateParams(
      address(updates[0].asset),
      IDefaultInterestRateStrategyV2.InterestRateData({
        optimalUsageRatio: uint16(updates[0].params.optimalUsageRatio),
        baseVariableBorrowRate: uint32(updates[0].params.baseVariableBorrowRate),
        variableRateSlope1: uint32(updates[0].params.variableRateSlope1),
        variableRateSlope2: uint32(updates[0].params.variableRateSlope2)
      })
    );
  }
}
