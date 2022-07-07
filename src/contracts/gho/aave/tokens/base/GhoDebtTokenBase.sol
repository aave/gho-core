// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';
import {ICreditDelegationToken} from '../../../dependencies/aave-tokens/interfaces/ICreditDelegationToken.sol';
import {IDebtTokenBase} from '../../../dependencies/aave-tokens/interfaces/IDebtTokenBase.sol';
import {ILendingPool} from '../../../dependencies/aave-core-v8/interfaces/ILendingPool.sol';
import {Errors} from '../../../dependencies/aave-core-v8/protocol/libraries/helpers/Errors.sol';

// Gho Imports
import {GhoIncentivizedERC20} from './GhoIncentivizedERC20.sol';

/**
 * @title DebtTokenBase
 * @notice Base contract for different types of debt tokens, like StableDebtToken or VariableDebtToken
 * @author Aave
 */
abstract contract GhoDebtTokenBase is
  GhoIncentivizedERC20,
  VersionedInitializable,
  ICreditDelegationToken,
  IDebtTokenBase
{
  address public immutable UNDERLYING_ASSET_ADDRESS;
  ILendingPool public immutable POOL;

  mapping(address => mapping(address => uint256)) internal _borrowAllowances;

  // Gho STORAGE
  mapping(address => uint256) internal _balanceFromInterest;
  address internal _ghoAToken;

  modifier onlyAToken() {
    require(_ghoAToken == msg.sender, 'CALLER_NOT_A_TOKEN');
    _;
  }

  /**
   * @dev Only lending pool can call functions marked by this modifier
   **/
  modifier onlyLendingPool() {
    require(_msgSender() == address(POOL), Errors.CT_CALLER_MUST_BE_LENDING_POOL);
    _;
  }

  /**
   * @dev The metadata of the token will be set on the proxy, that the reason of
   * passing "NULL" and 0 as metadata
   */
  constructor(
    address pool,
    address underlyingAssetAddress,
    string memory name,
    string memory symbol,
    address incentivesController
  ) GhoIncentivizedERC20(name, symbol, 18, incentivesController) {
    POOL = ILendingPool(pool);
    UNDERLYING_ASSET_ADDRESS = underlyingAssetAddress;
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
  ) public initializer {
    _setName(name);
    _setSymbol(symbol);
    _setDecimals(decimals);

    emit Initialized(
      UNDERLYING_ASSET_ADDRESS,
      address(POOL),
      address(_incentivesController),
      decimals,
      name,
      symbol,
      ''
    );
  }

  function getBalanceFromInterest(address user) external view returns (uint256) {
    return _balanceFromInterest[user];
  }

  function decreaseBalanceFromInterest(address user, uint256 amount) external onlyAToken {
    _balanceFromInterest[user] -= amount;
  }

  /**
   * @dev delegates borrowing power to a user on the specific debt token
   * @param delegatee the address receiving the delegated borrowing power
   * @param amount the maximum amount being delegated. Delegation will still
   * respect the liquidation constraints (even if delegated, a delegatee cannot
   * force a delegator HF to go below 1)
   **/
  function approveDelegation(address delegatee, uint256 amount) external override {
    _borrowAllowances[_msgSender()][delegatee] = amount;
    emit BorrowAllowanceDelegated(_msgSender(), delegatee, UNDERLYING_ASSET_ADDRESS, amount);
  }

  /**
   * @dev returns the borrow allowance of the user
   * @param fromUser The user to giving allowance
   * @param toUser The user to give allowance to
   * @return the current allowance of toUser
   **/
  function borrowAllowance(address fromUser, address toUser)
    external
    view
    override
    returns (uint256)
  {
    return _borrowAllowances[fromUser][toUser];
  }

  /**
   * @dev Being non transferrable, the debt token does not implement any of the
   * standard ERC20 functions for transfer and allowance.
   **/
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    recipient;
    amount;
    revert('TRANSFER_NOT_SUPPORTED');
  }

  function allowance(address owner, address spender)
    public
    view
    virtual
    override
    returns (uint256)
  {
    owner;
    spender;
    revert('ALLOWANCE_NOT_SUPPORTED');
  }

  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    spender;
    amount;
    revert('APPROVAL_NOT_SUPPORTED');
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override returns (bool) {
    sender;
    recipient;
    amount;
    revert('TRANSFER_NOT_SUPPORTED');
  }

  function increaseAllowance(address spender, uint256 addedValue)
    public
    virtual
    override
    returns (bool)
  {
    spender;
    addedValue;
    revert('ALLOWANCE_NOT_SUPPORTED');
  }

  function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    virtual
    override
    returns (bool)
  {
    spender;
    subtractedValue;
    revert('ALLOWANCE_NOT_SUPPORTED');
  }

  function _decreaseBorrowAllowance(
    address delegator,
    address delegatee,
    uint256 amount
  ) internal {
    uint256 newAllowance = _borrowAllowances[delegator][delegatee] - amount;

    _borrowAllowances[delegator][delegatee] = newAllowance;

    emit BorrowAllowanceDelegated(delegator, delegatee, UNDERLYING_ASSET_ADDRESS, newAllowance);
  }
}
