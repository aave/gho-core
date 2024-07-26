// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {FixedFeeStrategy} from '../facilitators/gsm/feeStrategy/FixedFeeStrategy.sol';
import {IGsm} from '../facilitators/gsm/interfaces/IGsm.sol';
import {IGsmFeeStrategy} from '../facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {IGhoGsmSteward} from './interfaces/IGhoGsmSteward.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';

/**
 * @title GhoGsmSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the GSM
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 * @dev Requires role GSM_CONFIGURATOR_ROLE on the GhoGsm contract
 */
contract GhoGsmSteward is Ownable, RiskCouncilControlled, IGhoGsmSteward {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @inheritdoc IGhoGsmSteward
  uint256 public constant GSM_FEE_RATE_CHANGE_MAX = 0.0050e4; // 0.50%

  /// @inheritdoc IGhoGsmSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IGhoGsmSteward
  function RISK_COUNCIL() public view override returns (address) {
    return COUNCIL;
  }

  mapping(address => GsmDebounce) internal _gsmTimelocksByAddress;

  mapping(uint256 => mapping(uint256 => address)) internal _gsmFeeStrategiesByRates;
  EnumerableSet.AddressSet internal _gsmFeeStrategies;

  /**
   * @dev Only methods that are not timelocked can be called if marked by this modifier.
   */
  modifier notTimelocked(uint40 timelock) {
    require(block.timestamp - timelock > MINIMUM_DELAY, 'DEBOUNCE_NOT_RESPECTED');
    _;
  }

  /**
   * @dev Constructor
   * @param owner The address of the owner of the contract
   * @param riskCouncil The address of the risk council
   */
  constructor(address owner, address riskCouncil) RiskCouncilControlled(riskCouncil) {
    require(owner != address(0), 'INVALID_OWNER');

    _transferOwnership(owner);
  }

  /**
   * @inheritdoc IGhoGsmSteward
   */
  function updateGsmExposureCap(
    address gsm,
    uint128 newExposureCap
  ) external onlyRiskCouncil notTimelocked(_gsmTimelocksByAddress[gsm].gsmExposureCapLastUpdated) {
    uint128 currentExposureCap = IGsm(gsm).getExposureCap();
    require(
      _isDifferenceLowerThanMax(currentExposureCap, newExposureCap, currentExposureCap),
      'INVALID_EXPOSURE_CAP_UPDATE'
    );

    _gsmTimelocksByAddress[gsm].gsmExposureCapLastUpdated = uint40(block.timestamp);

    IGsm(gsm).updateExposureCap(newExposureCap);
  }

  /**
   * @inheritdoc IGhoGsmSteward
   */
  function updateGsmBuySellFees(
    address gsm,
    uint256 buyFee,
    uint256 sellFee
  ) external onlyRiskCouncil notTimelocked(_gsmTimelocksByAddress[gsm].gsmFeeStrategyLastUpdated) {
    address currentFeeStrategy = IGsm(gsm).getFeeStrategy();
    require(currentFeeStrategy != address(0), 'GSM_FEE_STRATEGY_NOT_FOUND');

    uint256 currentBuyFee = IGsmFeeStrategy(currentFeeStrategy).getBuyFee(1e4);
    uint256 currentSellFee = IGsmFeeStrategy(currentFeeStrategy).getSellFee(1e4);
    require(
      _isDifferenceLowerThanMax(currentBuyFee, buyFee, GSM_FEE_RATE_CHANGE_MAX),
      'INVALID_BUY_FEE_UPDATE'
    );
    require(
      _isDifferenceLowerThanMax(currentSellFee, sellFee, GSM_FEE_RATE_CHANGE_MAX),
      'INVALID_SELL_FEE_UPDATE'
    );

    address cachedStrategyAddress = _gsmFeeStrategiesByRates[buyFee][sellFee];
    if (cachedStrategyAddress == address(0)) {
      FixedFeeStrategy newRateStrategy = new FixedFeeStrategy(buyFee, sellFee);
      cachedStrategyAddress = address(newRateStrategy);
      _gsmFeeStrategiesByRates[buyFee][sellFee] = cachedStrategyAddress;
      _gsmFeeStrategies.add(cachedStrategyAddress);
    }

    _gsmTimelocksByAddress[gsm].gsmFeeStrategyLastUpdated = uint40(block.timestamp);

    IGsm(gsm).updateFeeStrategy(cachedStrategyAddress);
  }

  /**
   * @inheritdoc IGhoGsmSteward
   */
  function getGsmTimelocks(address gsm) external view returns (GsmDebounce memory) {
    return _gsmTimelocksByAddress[gsm];
  }

  /**
   * @inheritdoc IGhoGsmSteward
   */
  function getGsmFeeStrategies() external view returns (address[] memory) {
    return _gsmFeeStrategies.values();
  }

  /**
   * @dev Ensures that the change difference is lower than max.
   * @param from current value
   * @param to new value
   * @param max maximum difference between from and to
   * @return bool true if difference between values lower than max, false otherwise
   */
  function _isDifferenceLowerThanMax(
    uint256 from,
    uint256 to,
    uint256 max
  ) internal pure returns (bool) {
    return from < to ? to - from <= max : from - to <= max;
  }
}
