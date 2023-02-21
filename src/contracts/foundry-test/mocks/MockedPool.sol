// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GhoVariableDebtToken} from '../../facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {GhoAToken} from '../../facilitators/aave/tokens/GhoAToken.sol';
import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {GhoDiscountRateStrategy} from '../../facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {GhoInterestRateStrategy} from '../../facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
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

/**
 * @dev MockedPool removes assets and users validations from Pool contract.
 */
contract MockedPool is Pool {
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  GhoVariableDebtToken public DEBT_TOKEN;
  GhoAToken public ATOKEN;
  address public GHO;

  constructor(IPoolAddressesProvider provider) Pool(provider) {}

  function setGhoTokens(GhoVariableDebtToken ghoDebtToken, GhoAToken ghoAToken) external {
    DEBT_TOKEN = ghoDebtToken;
    ATOKEN = ghoAToken;
    GHO = ghoAToken.UNDERLYING_ASSET_ADDRESS();
    _reserves[GHO].init(
      address(ATOKEN),
      address(new StableDebtToken(IPool(address(this)))),
      address(DEBT_TOKEN),
      address(new GhoInterestRateStrategy(2e25))
    );
  }

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) public override(Pool) {}

  function borrow(
    address,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) public override(Pool) {
    DataTypes.ReserveData storage reserve = _reserves[GHO];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();
    reserve.updateState(reserveCache);

    DEBT_TOKEN.mint(msg.sender, msg.sender, amount, reserveCache.nextVariableBorrowIndex);

    reserve.updateInterestRates(reserveCache, GHO, 0, amount);

    ATOKEN.transferUnderlyingTo(msg.sender, amount);
  }

  function repay(
    address,
    uint256 amount,
    uint256 interestRateMode,
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
}
