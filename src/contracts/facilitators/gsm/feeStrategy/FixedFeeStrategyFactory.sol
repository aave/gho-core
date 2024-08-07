/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {IFixedFeeStrategyFactory} from './interfaces/IFixedFeeStrategyFactory.sol';
import {IGsmFeeStrategy} from 'src/contracts/facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {FixedFeeStrategy} from './FixedFeeStrategy.sol';

/**
 * @title FixedFeeStrategyFactory
 * @author Aave Labs
 * @notice Factory contract to create and keep record of Gsm Fee contracts
 * @dev Works for fixed fee strategies (percentage based)
 */
contract FixedFeeStrategyFactory is VersionedInitializable, IFixedFeeStrategyFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev buyFee => sellFee => feeStrategy
  mapping(uint256 => mapping(uint256 => address)) internal _gsmFeeStrategiesByFees;
  EnumerableSet.AddressSet internal _gsmFeeStrategies;

  /**
   * @notice FixedFeeStrategyFactory initializer
   * @param feeStrategiesList List of fee strategies
   * @dev Assumes that the addresses provided are deployed fee strategies.
   */
  function initialize(address[] memory feeStrategiesList) external initializer {
    for (uint256 i = 0; i < feeStrategiesList.length; i++) {
      address feeStrategy = feeStrategiesList[i];
      uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
      uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);

      _gsmFeeStrategiesByFees[buyFee][sellFee] = feeStrategy;
      _gsmFeeStrategies.add(feeStrategy);

      emit FeeStrategyCreated(feeStrategy, buyFee, sellFee);
    }
  }

  ///@inheritdoc IFixedFeeStrategyFactory
  function createStrategies(
    uint256[] memory buyFeeList,
    uint256[] memory sellFeeList
  ) external returns (address[] memory) {
    require(buyFeeList.length == sellFeeList.length, 'INVALID_FEE_LIST');
    address[] memory strategies = new address[](buyFeeList.length);
    for (uint256 i = 0; i < buyFeeList.length; i++) {
      uint256 buyFee = buyFeeList[i];
      uint256 sellFee = sellFeeList[i];
      address cachedStrategy = _gsmFeeStrategiesByFees[buyFee][sellFee];

      if (cachedStrategy == address(0)) {
        cachedStrategy = address(new FixedFeeStrategy(buyFee, sellFee));
        _gsmFeeStrategiesByFees[buyFee][sellFee] = cachedStrategy;
        _gsmFeeStrategies.add(cachedStrategy);

        emit FeeStrategyCreated(cachedStrategy, buyFee, sellFee);
      }

      strategies[i] = cachedStrategy;
    }

    return strategies;
  }

  ///@inheritdoc IFixedFeeStrategyFactory
  function getFixedFeeStrategies() external view returns (address[] memory) {
    return _gsmFeeStrategies.values();
  }

  ///@inheritdoc IFixedFeeStrategyFactory
  function getStrategyByFees(uint256 buyFee, uint256 sellFee) external view returns (address) {
    return _gsmFeeStrategiesByFees[buyFee][sellFee];
  }

  ///@inheritdoc IFixedFeeStrategyFactory
  function REVISION() public pure virtual override returns (uint256) {
    return 1;
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return REVISION();
  }
}
