// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {ILendingPool} from '../../../dependencies/aave-core/interfaces/ILendingPool.sol';
import {ILendingPoolAddressesProvider} from '../../../dependencies/aave-core/interfaces/ILendingPoolAddressesProvider.sol';
import {Errors} from '../../../dependencies/aave-core/protocol/libraries/helpers/Errors.sol';
import {IERC20} from '../../../dependencies/aave-core/dependencies/openzeppelin/contracts/IERC20.sol';
import {PercentageMath} from '../../../dependencies/aave-core/protocol/libraries/math/PercentageMath.sol';
import {WadRayMath} from '../../../dependencies/aave-core/protocol/libraries/math/WadRayMath.sol';
import {DebtTokenBase} from './DebtTokenBase.sol';

import {IAnteiVariableDebtToken} from '../interfaces/IAnteiVariableDebtToken.sol';

/**
 * @title AnteiDebtTokenBase
 * @notice Base debt contract for Antei for account for discounts and balance from interest
 * @author Aave
 */
abstract contract AnteiDebtTokenBase is DebtTokenBase, IAnteiVariableDebtToken {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  address public immutable ADDRESSES_PROVIDER;

  uint256 internal _lastGlobalIndex;
  uint256 internal _totalWorkingSupply;
  uint256 internal _totalDiscountTokenSupplied;
  uint256 internal _integrateDiscount;

  uint256 public constant CONSTANT1 = 4e17;
  uint256 public constant CONSTANT2 = 1e18 - CONSTANT1;

  mapping(address => uint256) internal _balanceFromInterest;
  mapping(address => uint256) internal _workingBalanceOf;
  mapping(address => uint256) internal _integrateDiscountOf;
  address internal _anteiAToken;
  uint16 internal _discountRate;
  uint16 internal _maxDiscountRate;

  IERC20 _discountToken;

  /**
   * @dev Only the AnteiAToken an call functions marked by this modifier
   **/
  modifier onlyAToken() {
    require(_anteiAToken == msg.sender, 'CALLER_NOT_A_TOKEN');
    _;
  }

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
   * @dev The metadata of the token will be set on the proxy, that the reason of
   * passing "NULL" and 0 as metadata
   */
  constructor(
    address pool,
    address underlyingAsset,
    string memory name,
    string memory symbol,
    address incentivesController,
    address addressesProvider
  ) public DebtTokenBase(pool, underlyingAsset, name, symbol, incentivesController) {
    ADDRESSES_PROVIDER = addressesProvider;
  }

  /**
   * @dev Initializes the debt token.
   * @param name The name of the token
   * @param symbol The symbol of the token
   * @param decimals The decimals of the token
   */
  function initialize(
    uint8 decimals,
    string memory name,
    string memory symbol
  ) public override initializer {
    _integrateDiscount = 1e30;
    super.initialize(decimals, name, symbol);
  }

  function setAToken(address anteiAToken) external override onlyLendingPoolAdmin {
    require(_anteiAToken == address(0), 'ATOKEN_ALREADY_SET');
    _anteiAToken = anteiAToken;
    emit ATokenSet(anteiAToken);
  }

  function getAToken() external view override returns (address) {
    return _anteiAToken;
  }

  function setDiscountToken(address discountToken) external override onlyLendingPoolAdmin {
    address previousDiscountToken = address(_discountToken);
    _discountToken = IERC20(discountToken);
    emit DiscountTokenSet(previousDiscountToken, discountToken);
  }

  function getDiscountToken() external view override returns (address) {
    return address(_discountToken);
  }

  function setDiscountRate(uint256 discountRate) external override onlyLendingPoolAdmin {
    require(discountRate <= 10000, 'DISCOUNT_RATE_TOO_LARGE');
    uint256 previousDiscountRate = _discountRate;
    _discountRate = uint16(discountRate);
    emit DiscountRateSet(previousDiscountRate, discountRate);
  }

  function getDiscountRate() external view override returns (uint256) {
    return _discountRate;
  }

  function setMaxDiscountRate(uint256 maxDiscountRate) external override onlyLendingPoolAdmin {
    require(maxDiscountRate <= 10000, 'MAX_DISCOUNT_RATE_TOO_LARGE');
    uint256 previousMaxDiscountRate = _maxDiscountRate;
    _maxDiscountRate = uint16(maxDiscountRate);
    emit MaxDiscountRateSet(previousMaxDiscountRate, maxDiscountRate);
  }

  function getMaxDiscountRate() external view override returns (uint256) {
    return _maxDiscountRate;
  }

  function decreaseBalanceFromInterest(address user, uint256 amount) external override onlyAToken {
    uint256 previousBalanceFromInterest = _balanceFromInterest[user];
    uint256 updatedBalanceFromInterest = previousBalanceFromInterest - amount;
    _balanceFromInterest[user] = updatedBalanceFromInterest;
    emit BalanceFromInterestReduced(user, previousBalanceFromInterest, updatedBalanceFromInterest);
  }

  function getBalanceFromInterest(address user) external view override returns (uint256) {
    return _balanceFromInterest[user];
  }

  function _checkpointIntegrateDiscount(uint256 index) internal returns (uint256) {
    if (index != _lastGlobalIndex) {
      uint256 integrateDiscount = _calculateIntegrateDiscount(index);

      _lastGlobalIndex = index;
      _integrateDiscount = integrateDiscount;
      return integrateDiscount;
    } else {
      return _integrateDiscount;
    }
  }

  function _calculateIntegrateDiscount(uint256 index) internal view returns (uint256) {
    // calculate debt accrued since last user action
    uint256 totalSupplyScaled = super.totalSupply();
    uint256 debtIncrease = totalSupplyScaled.rayMul(index) -
      totalSupplyScaled.rayMul(_lastGlobalIndex);

    // sum of discount available since last global update
    uint256 discountsAvailable = debtIncrease.percentMul(_discountRate);

    // accumulate _integrateDiscount
    uint256 integrateDiscount = _integrateDiscount;
    uint256 totalWorkingSupply = _totalWorkingSupply;

    if (totalWorkingSupply != 0) {
      integrateDiscount = integrateDiscount.add(
        discountsAvailable.mul(1e18).div(totalWorkingSupply)
      );
    }

    return integrateDiscount;
  }

  function _updateWorkingBalance(
    address user,
    uint256 index,
    uint256 previousBalance,
    uint256 discountTokenBalance
  ) internal {
    // if the previous balance was zero - add discount balance to total tokens
    if (previousBalance == 0) {
      _totalDiscountTokenSupplied = _totalDiscountTokenSupplied.add(discountTokenBalance);
    }

    // if the current debt balance is zero - remove discount balance from total tokens
    // TODO: account for dust
    uint256 scaledBalance = super.balanceOf(user);
    if (scaledBalance == 0) {
      _totalDiscountTokenSupplied = _totalDiscountTokenSupplied.sub(discountTokenBalance);
    }

    uint256 asdBalance = scaledBalance.rayMul(index);
    uint256 weightedAsdBalance = CONSTANT1.wadMul(asdBalance);
    uint256 weightedDiscountTokenBalance = _totalDiscountTokenSupplied == 0
      ? 0
      : CONSTANT2.wadMul(super.totalSupply().rayMul(index)).wadMul(
        discountTokenBalance.wadDiv(_totalDiscountTokenSupplied)
      );
    uint256 weightedBalance = weightedAsdBalance.add(weightedDiscountTokenBalance);

    if (weightedBalance >= asdBalance) {
      _totalWorkingSupply = _totalWorkingSupply.add(asdBalance) - _workingBalanceOf[user];
      _workingBalanceOf[user] = asdBalance;
    } else {
      _totalWorkingSupply = _totalWorkingSupply.add(weightedBalance) - _workingBalanceOf[user];
      _workingBalanceOf[user] = weightedBalance;
    }
  }
}
