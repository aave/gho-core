// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {WadRayMath} from '../../dependencies/aave-core/protocol/libraries/math/WadRayMath.sol';
import {SafeMath} from '../../dependencies/aave-core/dependencies/openzeppelin/contracts/SafeMath.sol';
import {Errors} from '../../dependencies/aave-core/protocol/libraries/helpers/Errors.sol';
import {IAaveIncentivesController} from '../../dependencies/aave-tokens/interfaces/IAaveIncentivesController.sol';
import {IVariableDebtToken} from '../../dependencies/aave-tokens/interfaces/IVariableDebtToken.sol';

// Antei Imports
import {AnteiDebtTokenBase} from './base/AnteiDebtTokenBase.sol';

/**
 * @title VariableDebtToken
 * @notice Implements a variable debt token to track the borrowing positions of users
 * at variable rate mode
 * @author Aave
 **/
contract AnteiVariableDebtToken is AnteiDebtTokenBase, IVariableDebtToken {
  using WadRayMath for uint256;

  uint256 public constant DEBT_TOKEN_REVISION = 0x2;

  constructor(
    address pool,
    address underlyingAsset,
    string memory name,
    string memory symbol,
    address incentivesController,
    address addressesProvider
  )
    public
    AnteiDebtTokenBase(pool, underlyingAsset, name, symbol, incentivesController, addressesProvider)
  {}

  /**
   * @dev Gets the revision of the stable debt token implementation
   * @return The debt token implementation revision
   **/
  function getRevision() internal pure virtual override returns (uint256) {
    return DEBT_TOKEN_REVISION;
  }

  /**
   * @dev Calculates the accumulated debt balance of the user
   * @return The debt balance of the user
   **/
  function balanceOf(address user) public view virtual override returns (uint256) {
    uint256 scaledBalance = super.balanceOf(user);

    if (scaledBalance == 0) {
      return 0;
    }

    return scaledBalance.rayMul(POOL.getReserveNormalizedVariableDebt(UNDERLYING_ASSET_ADDRESS));
  }

  struct DiscountVariables {
    uint256 integrateDiscount;
    uint256 workingBalance;
    uint256 userDiscount;
    uint256 maxDiscount;
  }

  struct MintVariables {
    uint256 amountScaled;
    uint256 previousBalance;
    uint256 previousIndex;
    uint256 balanceIncrease;
    uint256 discountTokenBalance;
    uint256 scaledUserDiscount;
  }

  /**
   * @dev Mints debt token to the `onBehalfOf` address
   * -  Only callable by the LendingPool
   * @param user The address receiving the borrowed underlying, being the delegatee in case
   * of credit delegate, or same as `onBehalfOf` otherwise
   * @param onBehalfOf The address receiving the debt tokens
   * @param amount The amount of debt being minted
   * @param index The variable debt index of the reserve
   * @return `true` if the the previous balance of the user is 0
   **/
  function mint(
    address user,
    address onBehalfOf,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool returns (bool) {
    if (user != onBehalfOf) {
      _decreaseBorrowAllowance(onBehalfOf, user, amount);
    }

    MintVariables memory mv;
    mv.amountScaled = amount.rayDiv(index);
    require(mv.amountScaled != 0, Errors.CT_INVALID_MINT_AMOUNT);

    mv.previousBalance = super.balanceOf(onBehalfOf);
    mv.previousIndex = _previousIndex[onBehalfOf];
    mv.balanceIncrease = mv.previousBalance.rayMul(index).sub(
      mv.previousBalance.rayMul(mv.previousIndex)
    );

    // check if user holds discount token
    // if yes calculate a scaled version of their discount
    mv.discountTokenBalance = _discountToken.balanceOf(onBehalfOf);
    if (mv.discountTokenBalance != 0) {
      DiscountVariables memory dv;
      // update the amount of discounts available
      dv.integrateDiscount = _checkpointIntegrateDiscount(index);

      // if the time has passed since the users last action, calculate their discount
      if (index != mv.previousIndex) {
        dv.workingBalance = _workingBalanceOf[onBehalfOf];
        dv.userDiscount = dv
          .workingBalance
          .mul(dv.integrateDiscount.sub(_integrateDiscountOf[onBehalfOf]))
          .div(1e18);

        // updated the users last integrate discount
        _integrateDiscountOf[onBehalfOf] = dv.integrateDiscount;

        dv.maxDiscount = mv.balanceIncrease.percentMul(_maxDiscountRate);
        if (dv.userDiscount > dv.maxDiscount) {
          dv.userDiscount = dv.maxDiscount;
        }
        mv.balanceIncrease = mv.balanceIncrease - dv.userDiscount;
        mv.scaledUserDiscount = dv.userDiscount.rayDiv(index);
      }
    }

    _balanceFromInterest[onBehalfOf] = _balanceFromInterest[onBehalfOf].add(mv.balanceIncrease);
    _previousIndex[onBehalfOf] = index;

    if (mv.amountScaled > mv.scaledUserDiscount) {
      _mint(onBehalfOf, mv.amountScaled - mv.scaledUserDiscount);
    } else {
      _burn(onBehalfOf, mv.scaledUserDiscount - mv.amountScaled);
    }

    _updateWorkingBalance(onBehalfOf, mv.previousBalance, mv.discountTokenBalance);

    emit Transfer(address(0), onBehalfOf, amount);
    emit Mint(user, onBehalfOf, amount, index);
    return mv.previousBalance == 0;
  }

  /**
   * @dev Burns user variable debt
   * - Only callable by the LendingPool
   * @param user The user whose debt is getting burned
   * @param amount The amount getting burned
   * @param index The variable debt index of the reserve
   **/
  function burn(
    address user,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool {
    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled != 0, Errors.CT_INVALID_BURN_AMOUNT);

    uint256 previousBalance = super.balanceOf(user);
    uint256 balanceIncrease = previousBalance.rayMul(index).sub(
      previousBalance.rayMul(_previousIndex[user])
    );

    _previousIndex[user] = index;
    _balanceFromInterest[user] += balanceIncrease;

    _burn(user, amountScaled);

    emit Transfer(user, address(0), amount);
    emit Burn(user, amount, index);
  }

  /**
   * @dev Returns the principal debt balance of the user from
   * @return The debt balance of the user since the last burn/mint action
   **/
  function scaledBalanceOf(address user) public view virtual override returns (uint256) {
    return super.balanceOf(user);
  }

  /**
   * @dev Returns the total supply of the variable debt token. Represents the total debt accrued by the users
   * @return The total supply
   **/
  function totalSupply() public view virtual override returns (uint256) {
    return
      super.totalSupply().rayMul(POOL.getReserveNormalizedVariableDebt(UNDERLYING_ASSET_ADDRESS));
  }

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return the scaled total supply
   **/
  function scaledTotalSupply() public view virtual override returns (uint256) {
    return super.totalSupply();
  }

  /**
   * @dev Returns the principal balance of the user and principal total supply.
   * @param user The address of the user
   * @return The principal balance of the user
   * @return The principal total supply
   **/
  function getScaledUserBalanceAndSupply(address user)
    external
    view
    override
    returns (uint256, uint256)
  {
    return (super.balanceOf(user), super.totalSupply());
  }

  /**
   * @dev Returns the address of the incentives controller contract
   * @return incentives address
   **/
  function getIncentivesController() external view override returns (IAaveIncentivesController) {
    return _incentivesController;
  }
}
