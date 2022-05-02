// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {ILendingPool} from '../../../dependencies/aave-core/interfaces/ILendingPool.sol';
import {ILendingPoolAddressesProvider} from '../../../dependencies/aave-core/interfaces/ILendingPoolAddressesProvider.sol';
import {Errors} from '../../../dependencies/aave-core/protocol/libraries/helpers/Errors.sol';
import {IERC20} from '../../../dependencies/aave-core/dependencies/openzeppelin/contracts/IERC20.sol';
import {DebtTokenBase} from './DebtTokenBase.sol';

import {IAnteiVariableDebtToken} from '../interfaces/IAnteiVariableDebtToken.sol';

/**
 * @title AnteiDebtTokenBase
 * @notice Base debt contract for Antei for account for discounts and balance from interest
 * @author Aave
 */
abstract contract AnteiDebtTokenBase is DebtTokenBase, IAnteiVariableDebtToken {
  address public immutable ADDRESSES_PROVIDER;

  mapping(address => uint256) internal _balanceFromInterest;
  address internal _anteiAToken;

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
    emit DiscountTokenSet(discountToken);
  }

  function getDiscountToken() external view override returns (address) {
    return address(_discountToken);
  }

  function getBalanceFromInterest(address user) external view override returns (uint256) {
    return _balanceFromInterest[user];
  }

  function decreaseBalanceFromInterest(address user, uint256 amount) external override onlyAToken {
    uint256 previousBalanceFromInterest = _balanceFromInterest[user];
    uint256 updatedBalanceFromInterest = previousBalanceFromInterest - amount;
    _balanceFromInterest[user] = updatedBalanceFromInterest;
    emit BalanceFromInterestReduced(user, previousBalanceFromInterest, updatedBalanceFromInterest);
  }
}
