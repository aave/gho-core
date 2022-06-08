// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {WadRayMath} from '../../dependencies/aave-core/protocol/libraries/math/WadRayMath.sol';
import {PercentageMath} from '../../dependencies/aave-core/protocol/libraries/math/PercentageMath.sol';
import {Errors} from '../../dependencies/aave-core/protocol/libraries/helpers/Errors.sol';
import {IERC20} from '../../dependencies/aave-core/dependencies/openzeppelin/contracts/IERC20.sol';
import {IAaveIncentivesController} from '../../dependencies/aave-tokens/interfaces/IAaveIncentivesController.sol';

// Antei Imports
import {ILendingPoolAddressesProvider} from '../../dependencies/aave-core/interfaces/ILendingPoolAddressesProvider.sol';
import {IAnteiVariableDebtToken} from './interfaces/IAnteiVariableDebtToken.sol';
import {AnteiDebtTokenBase} from './base/AnteiDebtTokenBase.sol';
import {IAnteiDiscountRateStrategy} from './interfaces/IAnteiDiscountRateStrategy.sol';

/**
 * @title VariableDebtToken
 * @notice Implements a variable debt token to track the borrowing positions of users
 * at variable rate mode
 * @author Aave
 **/
contract AnteiVariableDebtToken is AnteiDebtTokenBase, IAnteiVariableDebtToken {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant DEBT_TOKEN_REVISION = 0x2;

  address public immutable ADDRESSES_PROVIDER;

  //AnteiStorage
  IAnteiDiscountRateStrategy internal _discountRateStrategy;
  IERC20 internal _stakedToken;
  mapping(address => uint256) internal _discounts;

  /**
   * @dev Only pool admin can call functions marked by this modifier.
   **/
  modifier onlyLendingPoolAdmin() {
    ILendingPoolAddressesProvider addressesProvider = ILendingPoolAddressesProvider(
      ADDRESSES_PROVIDER
    );
    require(addressesProvider.getPoolAdmin() == msg.sender, Errors.CALLER_NOT_POOL_ADMIN);
    _;
  }

  /**
   * @dev Only staked token can call functions marked by this modifier.
   **/
  modifier onlyStakedToken() {
    require(address(_stakedToken) == msg.sender, 'CALLER_NOT_DISCOUNT_TOKEN');
    _;
  }

  constructor(
    address pool,
    address underlyingAsset,
    string memory name,
    string memory symbol,
    address incentivesController,
    address addressesProvider
  ) public AnteiDebtTokenBase(pool, underlyingAsset, name, symbol, incentivesController) {
    ADDRESSES_PROVIDER = addressesProvider;
  }

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

    uint256 index = POOL.getReserveNormalizedVariableDebt(UNDERLYING_ASSET_ADDRESS);
    uint256 previousIndex = _previousIndex[user];
    uint256 balance = scaledBalance.rayMul(index);
    if (index == previousIndex) {
      return balance;
    }

    uint256 discountPercentage = _discounts[user];
    if (discountPercentage != 0) {
      uint256 balanceIncrease = balance.sub(scaledBalance.rayMul(previousIndex));
      uint256 discount = balanceIncrease.percentMul(discountPercentage);
      balance = balance - discount;
    }

    return balance;
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

    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled != 0, Errors.CT_INVALID_MINT_AMOUNT);

    uint256 previousBalance = super.balanceOf(onBehalfOf);
    uint256 balanceIncrease = previousBalance.rayMul(index).sub(
      previousBalance.rayMul(_previousIndex[onBehalfOf])
    );

    // skip applying discount in either case
    // 1) no balance increase
    // 2) user has no discount
    uint256 discountPercent = _discounts[onBehalfOf];
    uint256 discountScaled = 0;
    if (balanceIncrease != 0 && discountPercent != 0) {
      uint256 discount = balanceIncrease.percentMul(discountPercent);

      // skip checked division to
      // avoid rounding in the case where discountPercent = 100%
      // The index will never be 0
      uint256 discountScaled = (discount * WadRayMath.RAY) / index;

      balanceIncrease = balanceIncrease.sub(discount);
    }

    _previousIndex[onBehalfOf] = index;
    _balanceFromInterest[onBehalfOf] = _balanceFromInterest[onBehalfOf].add(balanceIncrease);

    // confirm the amount being borrowed is greater than the discount
    if (amountScaled > discountScaled) {
      // intentionally unchecked
      _mint(onBehalfOf, amountScaled - discountScaled);
    } else {
      _burn(onBehalfOf, discountScaled.add(amountScaled));
    }

    // always set the discount incase the strategy was updated
    _discounts[onBehalfOf] = _discountRateStrategy.calculateDiscountRate(
      super.balanceOf(onBehalfOf).rayMul(index),
      _stakedToken.balanceOf(onBehalfOf)
    );

    emit Transfer(address(0), onBehalfOf, amount);
    emit Mint(user, onBehalfOf, amount, index);
    return previousBalance == 0;
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

    // skip applying discount in either case
    // 1) no balance increase
    // 2) user has no discount
    uint256 discountPercent = _discounts[user];
    if (balanceIncrease != 0 && discountPercent != 0) {
      uint256 discount = balanceIncrease.percentMul(discountPercent);

      // skip checked division
      // avoids rounding in the case discount = 100%
      // index will never be 0
      uint256 discountScaled = (discount * WadRayMath.RAY) / index;

      balanceIncrease = balanceIncrease.sub(discount);
      amountScaled = amountScaled.add(discountScaled);
    }

    _previousIndex[user] = index;
    _balanceFromInterest[user] = _balanceFromInterest[user].add(balanceIncrease);

    _burn(user, amountScaled);

    _discounts[user] = _discountRateStrategy.calculateDiscountRate(
      super.balanceOf(user).rayMul(index),
      _stakedToken.balanceOf(user)
    );

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

  /// @inheritdoc IAnteiVariableDebtToken
  function setAToken(address anteiAToken) external override onlyLendingPoolAdmin {
    require(_anteiAToken == address(0), 'ATOKEN_ALREADY_SET');
    _anteiAToken = anteiAToken;
    emit ATokenSet(anteiAToken);
  }

  /// @inheritdoc IAnteiVariableDebtToken
  function getAToken() external view override returns (address) {
    return _anteiAToken;
  }

  /// @inheritdoc IAnteiVariableDebtToken
  function updateDiscountRateStrategy(address discountRateStrategy)
    external
    override
    onlyLendingPoolAdmin
  {
    address previousDiscountRateStrategy = address(_discountRateStrategy);
    _discountRateStrategy = IAnteiDiscountRateStrategy(discountRateStrategy);
    emit DiscountRateStrategyUpdated(previousDiscountRateStrategy, discountRateStrategy);
  }

  /// @inheritdoc IAnteiVariableDebtToken
  function getDiscountRateStrategy() external view override returns (address) {
    return address(_discountRateStrategy);
  }

  /// @inheritdoc IAnteiVariableDebtToken
  function updateStakedToken(address stakedToken) external override onlyLendingPoolAdmin {
    address previousStakedToken = address(_stakedToken);
    _stakedToken = IERC20(stakedToken);
    emit StakedTokenUpdated(previousStakedToken, stakedToken);
  }

  /// @inheritdoc IAnteiVariableDebtToken
  function getStakedToken() external view override returns (address) {
    return address(_stakedToken);
  }
}
