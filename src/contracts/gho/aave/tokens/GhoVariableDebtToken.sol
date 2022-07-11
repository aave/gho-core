// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {SafeCast} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';
import {IERC20} from '../../dependencies/aave-core/dependencies/openzeppelin/contracts/IERC20.sol';
import {ILendingPoolAddressesProvider} from '../../dependencies/aave-core/interfaces/ILendingPoolAddressesProvider.sol';
import {Errors} from '../../dependencies/aave-core-v8/protocol/libraries/helpers/Errors.sol';

// Gho Imports
import {IGhoVariableDebtToken} from './interfaces/IGhoVariableDebtToken.sol';
import {IAaveIncentivesController} from './interfaces/IAaveIncentivesController.sol';
import {IGhoDiscountRateStrategy} from './interfaces/IGhoDiscountRateStrategy.sol';
import {GhoDebtTokenBase} from './base/GhoDebtTokenBase.sol';

/**
 * @title VariableDebtToken
 * @notice Implements a variable debt token to track the borrowing positions of users
 * at variable rate mode
 * @author Aave
 **/
contract GhoVariableDebtToken is GhoDebtTokenBase, IGhoVariableDebtToken {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for uint256;

  uint256 public constant DEBT_TOKEN_REVISION = 0x2;

  address public immutable ADDRESSES_PROVIDER;

  // Corresponding AToken to this DebtToken
  address internal _ghoAToken;

  // Token that grants discounts off the debt interest
  IERC20 internal _discountToken;

  // Strategy of the discount rate to apply on debt interests
  IGhoDiscountRateStrategy internal _discountRateStrategy;

  struct GhoUserState {
    // Accumulated debt interest of the user
    uint128 accumulatedDebtInterest;
    // Discount percent of the user (expressed in bps)
    uint16 discountPercent;
    // Time when users discount can be rebalanced in seconds
    uint40 rebalanceTimestamp;
  }

  // Map of users address and their gho state data (userAddress => ghoUserState)
  mapping(address => GhoUserState) internal _ghoUserState;

  // Amount of time a user is entitled to a discount without performing additional actions
  uint256 internal _discountLockPeriod;

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
   * @dev Only discount token can call functions marked by this modifier.
   **/
  modifier onlyDiscountToken() {
    require(address(_discountToken) == msg.sender, 'CALLER_NOT_DISCOUNT_TOKEN');
    _;
  }

  /**
   * @dev Only AToken can call functions marked by this modifier.
   **/
  modifier onlyAToken() {
    require(_ghoAToken == msg.sender, 'CALLER_NOT_A_TOKEN');
    _;
  }

  constructor(
    address pool,
    address underlyingAsset,
    string memory name,
    string memory symbol,
    address incentivesController,
    address addressesProvider
  ) GhoDebtTokenBase(pool, underlyingAsset, name, symbol, incentivesController) {
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
    uint256 previousIndex = _userState[user].additionalData;
    uint256 balance = scaledBalance.rayMul(index);
    if (index == previousIndex) {
      return balance;
    }

    uint256 discountPercent = _ghoUserState[user].discountPercent;
    if (discountPercent != 0) {
      uint256 balanceIncrease = balance - scaledBalance.rayMul(previousIndex);
      uint256 discount = balanceIncrease.percentMul(discountPercent);
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
    uint256 discountPercent = _ghoUserState[onBehalfOf].discountPercent;
    (uint256 balanceIncrease, uint256 discountScaled) = _accrueDebtOnAction(
      onBehalfOf,
      previousBalance,
      discountPercent,
      index
    );

    // confirm the amount being borrowed is greater than the discount
    if (amountScaled > discountScaled) {
      _mint(onBehalfOf, amountScaled - discountScaled);
    } else {
      _burn(onBehalfOf, discountScaled - amountScaled);
    }

    refreshDiscountPercent(
      onBehalfOf,
      super.balanceOf(onBehalfOf).rayMul(index),
      _discountToken.balanceOf(onBehalfOf),
      discountPercent
    );

    uint256 amountToMint = amount + balanceIncrease;
    emit Transfer(address(0), onBehalfOf, amountToMint);
    emit Mint(user, onBehalfOf, amountToMint, balanceIncrease, index);

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
    uint256 discountPercent = _ghoUserState[user].discountPercent;
    (uint256 balanceIncrease, uint256 discountScaled) = _accrueDebtOnAction(
      user,
      previousBalance,
      discountPercent,
      index
    );

    _burn(user, amountScaled + discountScaled);

    refreshDiscountPercent(
      user,
      super.balanceOf(user).rayMul(index),
      _discountToken.balanceOf(user),
      discountPercent
    );

    if (balanceIncrease > amount) {
      uint256 amountToMint = balanceIncrease - amount;
      emit Transfer(address(0), user, amountToMint);
      emit Mint(user, user, amountToMint, balanceIncrease, index);
    } else {
      uint256 amountToBurn = amount - balanceIncrease;
      emit Transfer(user, address(0), amountToBurn);
      emit Burn(user, address(0), amountToBurn, balanceIncrease, index);
    }
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

  /// @inheritdoc IGhoVariableDebtToken
  function setAToken(address ghoAToken) external override onlyLendingPoolAdmin {
    require(_ghoAToken == address(0), 'ATOKEN_ALREADY_SET');
    _ghoAToken = ghoAToken;
    emit ATokenSet(ghoAToken);
  }

  /// @inheritdoc IGhoVariableDebtToken
  function getAToken() external view override returns (address) {
    return _ghoAToken;
  }

  /// @inheritdoc IGhoVariableDebtToken
  function updateDiscountRateStrategy(address discountRateStrategy)
    external
    override
    onlyLendingPoolAdmin
  {
    address previousDiscountRateStrategy = address(_discountRateStrategy);
    _discountRateStrategy = IGhoDiscountRateStrategy(discountRateStrategy);
    emit DiscountRateStrategyUpdated(previousDiscountRateStrategy, discountRateStrategy);
  }

  /// @inheritdoc IGhoVariableDebtToken
  function getDiscountRateStrategy() external view override returns (address) {
    return address(_discountRateStrategy);
  }

  /// @inheritdoc IGhoVariableDebtToken
  function updateDiscountToken(address discountToken) external override onlyLendingPoolAdmin {
    address previousDiscountToken = address(_discountToken);
    _discountToken = IERC20(discountToken);
    emit DiscountTokenUpdated(previousDiscountToken, discountToken);
  }

  /// @inheritdoc IGhoVariableDebtToken
  function getDiscountToken() external view override returns (address) {
    return address(_discountToken);
  }

  // @inheritdoc IGhoVariableDebtToken
  function updateDiscountDistribution(
    address sender,
    address recipient,
    uint256 senderDiscountTokenBalance,
    uint256 recipientDiscountTokenBalance,
    uint256 amount
  ) external override onlyDiscountToken {
    uint256 senderPreviousBalance = super.balanceOf(sender);
    uint256 recipientPreviousBalance = super.balanceOf(recipient);

    uint256 index = POOL.getReserveNormalizedVariableDebt(UNDERLYING_ASSET_ADDRESS);

    uint256 balanceIncrease;
    uint256 discountScaled;

    if (senderPreviousBalance > 0) {
      (balanceIncrease, discountScaled) = _accrueDebtOnAction(
        sender,
        senderPreviousBalance,
        _ghoUserState[sender].discountPercent,
        index
      );

      _burn(sender, discountScaled);

      refreshDiscountPercent(
        sender,
        super.balanceOf(sender).rayMul(index),
        senderDiscountTokenBalance - amount,
        _ghoUserState[sender].discountPercent
      );

      emit Transfer(address(0), sender, balanceIncrease);
      emit Mint(address(0), sender, balanceIncrease, balanceIncrease, index);
    }

    if (recipientPreviousBalance > 0) {
      (balanceIncrease, discountScaled) = _accrueDebtOnAction(
        recipient,
        recipientPreviousBalance,
        _ghoUserState[recipient].discountPercent,
        index
      );

      _burn(recipient, discountScaled);

      refreshDiscountPercent(
        recipient,
        super.balanceOf(recipient).rayMul(index),
        recipientDiscountTokenBalance + amount,
        _ghoUserState[recipient].discountPercent
      );

      emit Transfer(address(0), recipient, balanceIncrease);
      emit Mint(address(0), recipient, balanceIncrease, balanceIncrease, index);
    }
  }

  // @inheritdoc IGhoVariableDebtToken
  function getDiscountPercent(address user) external view override returns (uint256) {
    return _ghoUserState[user].discountPercent;
  }

  // @inheritdoc IGhoVariableDebtToken
  function getBalanceFromInterest(address user) external view override returns (uint256) {
    return _ghoUserState[user].accumulatedDebtInterest;
  }

  // @inheritdoc IGhoVariableDebtToken
  function decreaseBalanceFromInterest(address user, uint256 amount) external override onlyAToken {
    _ghoUserState[user].accumulatedDebtInterest = (_ghoUserState[user].accumulatedDebtInterest -
      amount).toUint128();
  }

  // @inheritdoc IGhoVariableDebtToken
  function rebalanceUserDiscountPercent(address user) external override {
    require(
      _ghoUserState[user].rebalanceTimestamp < block.timestamp &&
        _ghoUserState[user].rebalanceTimestamp != 0,
      'DISCOUNT_PERCENT_REBALANCE_CONDITION_NOT_MET'
    );

    uint256 index = POOL.getReserveNormalizedVariableDebt(UNDERLYING_ASSET_ADDRESS);
    uint256 previousBalance = super.balanceOf(user);
    uint256 discountPercent = _ghoUserState[user].discountPercent;

    (uint256 balanceIncrease, uint256 discountScaled) = _accrueDebtOnAction(
      user,
      previousBalance,
      discountPercent,
      index
    );

    _burn(user, discountScaled);

    refreshDiscountPercent(
      user,
      super.balanceOf(user).rayMul(index),
      _discountToken.balanceOf(user),
      discountPercent
    );

    emit Transfer(address(0), user, balanceIncrease);
    emit Mint(address(0), user, balanceIncrease, balanceIncrease, index);
  }

  // @inheritdoc IGhoVariableDebtToken
  function updateDiscountLockPeriod(uint256 newLockPeriod) external override onlyLendingPoolAdmin {
    uint256 oldLockPeriod = _discountLockPeriod;
    require(newLockPeriod <= type(uint40).max, "Value doesn't fit in 40 bits");
    _discountLockPeriod = uint40(newLockPeriod);
    emit DiscountLockPeriodUpdated(oldLockPeriod, newLockPeriod);
  }

  // @inheritdoc IGhoVariableDebtToken
  function getDiscountLockPeriod() external view override returns (uint256) {
    return _discountLockPeriod;
  }

  // @inheritdoc IGhoVariableDebtToken
  function getUserRebalanceTimestamp(address user) external view override returns (uint256) {
    return _ghoUserState[user].rebalanceTimestamp;
  }

  /**
   * @dev Accumulates debt of the user since last action.
   * @dev It skips applying discount in case there is no balance increase or discount percent is zero.
   * @param user The address of the user
   * @param previousBalance The previous balance of the user
   * @param discountPercent The discount percent
   * @param index The variable debt index of the reserve
   * @return The increase in scaled balance since the last action of `user`
   * @return The discounted amount in scaled balance off the balance increase
   */
  function _accrueDebtOnAction(
    address user,
    uint256 previousBalance,
    uint256 discountPercent,
    uint256 index
  ) internal returns (uint256, uint256) {
    uint256 balanceIncrease = previousBalance.rayMul(index) -
      previousBalance.rayMul(_userState[user].additionalData);

    uint256 discountScaled = 0;
    if (balanceIncrease != 0 && discountPercent != 0) {
      uint256 discount = balanceIncrease.percentMul(discountPercent);

      // skip checked division to
      // avoid rounding in the case discount = 100%
      // The index will never be 0
      discountScaled = (discount * WadRayMath.RAY) / index;

      balanceIncrease = balanceIncrease - discount;
    }

    _userState[user].additionalData = index.toUint128();

    _ghoUserState[user].accumulatedDebtInterest = (balanceIncrease +
      _ghoUserState[user].accumulatedDebtInterest).toUint128();

    return (balanceIncrease, discountScaled);
  }

  /**
   * @dev Updates the discount percent of the user according to current discount rate strategy
   * @param user The address of the user
   * @param balance The debt balance of the user
   * @param discountTokenBalance The discount token balance of the user
   * @param previousDiscountPercent The previous discount percent of the user
   */
  function refreshDiscountPercent(
    address user,
    uint256 balance,
    uint256 discountTokenBalance,
    uint256 previousDiscountPercent
  ) internal {
    uint256 newDiscountPercent = _discountRateStrategy.calculateDiscountRate(
      balance,
      discountTokenBalance
    );

    bool changed;
    if (previousDiscountPercent != newDiscountPercent) {
      _ghoUserState[user].discountPercent = newDiscountPercent.toUint16();
      changed = true;
    }

    if (newDiscountPercent != 0) {
      uint256 tempRebalanceTimestamp = block.timestamp + _discountLockPeriod;
      require(tempRebalanceTimestamp <= type(uint40).max, "Value doesn't fit in 40 bits");

      uint40 newRebalanceTimestamp = uint40(tempRebalanceTimestamp);
      _ghoUserState[user].rebalanceTimestamp = newRebalanceTimestamp;
      emit DiscountPercentLocked(user, newDiscountPercent, newRebalanceTimestamp);
    } else {
      if (changed) {
        _ghoUserState[user].rebalanceTimestamp = 0;
        emit DiscountPercentLocked(user, newDiscountPercent, 0);
      }
    }
  }
}
