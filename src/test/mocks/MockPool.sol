// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GhoVariableDebtToken} from '../../contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {GhoAToken} from '../../contracts/facilitators/aave/tokens/GhoAToken.sol';
import {IGhoToken} from '../../contracts/gho/interfaces/IGhoToken.sol';
import {GhoDiscountRateStrategy} from '../../contracts/facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {GhoInterestRateStrategy} from '../../contracts/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IAaveIncentivesController} from '@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol';
import {Pool} from '@aave/core-v3/contracts/protocol/pool/Pool.sol';
import {UserConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/UserConfiguration.sol';
import {ReserveConfiguration} from '@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {ReserveLogic} from '@aave/core-v3/contracts/protocol/libraries/logic/ReserveLogic.sol';
import {Helpers} from '@aave/core-v3/contracts/protocol/libraries/helpers/Helpers.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {StableDebtToken} from '@aave/core-v3/contracts/protocol/tokenization/StableDebtToken.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';

/**
 * @dev MockPool removes assets and users validations from Pool contract.
 */
contract MockPool is Pool {
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  GhoVariableDebtToken public DEBT_TOKEN;
  GhoAToken public ATOKEN;
  address public GHO;

  constructor(IPoolAddressesProvider provider) Pool(provider) {}

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  function setGhoTokens(GhoVariableDebtToken ghoDebtToken, GhoAToken ghoAToken) external {
    DEBT_TOKEN = ghoDebtToken;
    ATOKEN = ghoAToken;
    GHO = ghoAToken.UNDERLYING_ASSET_ADDRESS();
    _reserves[GHO].init(
      address(ATOKEN),
      address(new StableDebtToken(IPool(address(this)))),
      address(DEBT_TOKEN),
      address(new GhoInterestRateStrategy(address(0), 2e25))
    );
  }

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) public override(Pool) {}

  function borrow(
    address, // asset
    uint256 amount,
    uint256, // interestRateMode
    uint16, // referralCode
    address onBehalfOf
  ) public override(Pool) {
    DataTypes.ReserveData storage reserve = _reserves[GHO];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();
    reserve.updateState(reserveCache);

    DEBT_TOKEN.mint(msg.sender, onBehalfOf, amount, reserveCache.nextVariableBorrowIndex);

    reserve.updateInterestRates(reserveCache, GHO, 0, amount);

    ATOKEN.transferUnderlyingTo(onBehalfOf, amount);
  }

  function repay(
    address, // asset
    uint256 amount,
    uint256, // interestRateMode
    address onBehalfOf
  ) public override(Pool) returns (uint256) {
    DataTypes.ReserveData storage reserve = _reserves[GHO];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();
    reserve.updateState(reserveCache);

    uint256 paybackAmount = DEBT_TOKEN.balanceOf(onBehalfOf);

    if (amount < paybackAmount) {
      paybackAmount = amount;
    }

    DEBT_TOKEN.burn(onBehalfOf, paybackAmount, reserveCache.nextVariableBorrowIndex);

    reserve.updateInterestRates(reserveCache, GHO, 0, amount);

    IERC20(GHO).transferFrom(msg.sender, reserveCache.aTokenAddress, paybackAmount);

    ATOKEN.handleRepayment(msg.sender, onBehalfOf, paybackAmount);

    return paybackAmount;
  }

  function setReserveInterestRateStrategyAddress(
    address asset,
    address rateStrategyAddress
  ) external override {
    require(asset != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
    _reserves[asset].interestRateStrategyAddress = rateStrategyAddress;
  }

  function getReserveInterestRateStrategyAddress(address asset) public view returns (address) {
    return _reserves[asset].interestRateStrategyAddress;
  }
}
