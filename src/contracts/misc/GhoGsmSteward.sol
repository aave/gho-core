// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IGsm} from '../facilitators/gsm/interfaces/IGsm.sol';
import {IGsmFeeStrategy} from '../facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {IFixedFeeStrategyFactory} from '../facilitators/gsm/feeStrategy/interfaces/IFixedFeeStrategyFactory.sol';
import {IGhoGsmSteward} from './interfaces/IGhoGsmSteward.sol';
import {RiskCouncilControlled} from './RiskCouncilControlled.sol';

/**
 * @title GhoGsmSteward
 * @author Aave Labs
 * @notice Helper contract for managing parameters of the GSM
 * @dev Only the Risk Council is able to action contract's functions, based on specific conditions that have been agreed upon with the community.
 * @dev Requires role GSM_CONFIGURATOR_ROLE on every GSM contract to be managed
 */
contract GhoGsmSteward is RiskCouncilControlled, IGhoGsmSteward {
  /// @inheritdoc IGhoGsmSteward
  uint256 public constant GSM_FEE_RATE_CHANGE_MAX = 0.0050e4; // 0.50%

  /// @inheritdoc IGhoGsmSteward
  uint256 public constant MINIMUM_DELAY = 2 days;

  /// @inheritdoc IGhoGsmSteward
  address public immutable FIXED_FEE_STRATEGY_FACTORY;

  mapping(address => GsmDebounce) internal _gsmTimelocksByAddress;

  /**
   * @dev Only methods that are not timelocked can be called if marked by this modifier.
   */
  modifier notTimelocked(uint40 timelock) {
    require(block.timestamp - timelock > MINIMUM_DELAY, 'DEBOUNCE_NOT_RESPECTED');
    _;
  }

  /**
   * @dev Constructor
   * @param fixedFeeStrategyFactory The address of the Fixed Fee Strategy Factory
   * @param riskCouncil The address of the risk council
   */
  constructor(
    address fixedFeeStrategyFactory,
    address riskCouncil
  ) RiskCouncilControlled(riskCouncil) {
    require(fixedFeeStrategyFactory != address(0), 'INVALID_FIXED_FEE_STRATEGY_FACTORY');

    FIXED_FEE_STRATEGY_FACTORY = fixedFeeStrategyFactory;
  }

  /// @inheritdoc IGhoGsmSteward
  function updateGsmExposureCap(
    address gsm,
    uint128 newExposureCap
  ) external onlyRiskCouncil notTimelocked(_gsmTimelocksByAddress[gsm].gsmExposureCapLastUpdated) {
    uint128 currentExposureCap = IGsm(gsm).getExposureCap();
    require(newExposureCap != currentExposureCap, 'NO_CHANGE_IN_EXPOSURE_CAP');
    require(
      _isDifferenceLowerThanMax(currentExposureCap, newExposureCap, currentExposureCap),
      'INVALID_EXPOSURE_CAP_UPDATE'
    );

    _gsmTimelocksByAddress[gsm].gsmExposureCapLastUpdated = uint40(block.timestamp);

    IGsm(gsm).updateExposureCap(newExposureCap);
  }

  /// @inheritdoc IGhoGsmSteward
  function updateGsmBuySellFees(
    address gsm,
    uint256 buyFee,
    uint256 sellFee
  ) external onlyRiskCouncil notTimelocked(_gsmTimelocksByAddress[gsm].gsmFeeStrategyLastUpdated) {
    address currentFeeStrategy = IGsm(gsm).getFeeStrategy();

    if (currentFeeStrategy != address(0)) {
      uint256 currentBuyFee = IGsmFeeStrategy(currentFeeStrategy).getBuyFee(1e4);
      uint256 currentSellFee = IGsmFeeStrategy(currentFeeStrategy).getSellFee(1e4);
      require(buyFee != currentBuyFee || sellFee != currentSellFee, 'NO_CHANGE_IN_FEES');
      require(
        _isDifferenceLowerThanMax(currentBuyFee, buyFee, GSM_FEE_RATE_CHANGE_MAX),
        'INVALID_BUY_FEE_UPDATE'
      );
      require(
        _isDifferenceLowerThanMax(currentSellFee, sellFee, GSM_FEE_RATE_CHANGE_MAX),
        'INVALID_SELL_FEE_UPDATE'
      );
    }

    IFixedFeeStrategyFactory strategyFactory = IFixedFeeStrategyFactory(FIXED_FEE_STRATEGY_FACTORY);
    uint256[] memory buyFeeList = new uint256[](1);
    uint256[] memory sellFeeList = new uint256[](1);
    buyFeeList[0] = buyFee;
    sellFeeList[0] = sellFee;
    address strategy = strategyFactory.createStrategies(buyFeeList, sellFeeList)[0];

    _gsmTimelocksByAddress[gsm].gsmFeeStrategyLastUpdated = uint40(block.timestamp);

    IGsm(gsm).updateFeeStrategy(strategy);
  }

  /// @inheritdoc IGhoGsmSteward
  function getGsmTimelocks(address gsm) external view returns (GsmDebounce memory) {
    return _gsmTimelocksByAddress[gsm];
  }

  /// @inheritdoc IGhoGsmSteward
  function RISK_COUNCIL() public view override returns (address) {
    return riskCouncil;
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
