// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import {IVariableDebtToken} from '@aave/core-v3/contracts/interfaces/IVariableDebtToken.sol';

interface IGhoVariableDebtToken is IVariableDebtToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @param aToken GhoAToken contract
   **/
  event ATokenSet(address indexed aToken);

  /**
   * @dev Emitted when the GhoDiscountRateStrategy is updated
   * @param previousDiscountRateStrategy previous GhoDiscountRateStrategy
   * @param nextDiscountRateStrategy next GhoDiscountRateStrategy
   **/
  event DiscountRateStrategyUpdated(
    address indexed previousDiscountRateStrategy,
    address indexed nextDiscountRateStrategy
  );

  /**
   * @dev Emitted when the Discount Token is updated
   * @param previousDiscountToken previous discount token
   * @param nextDiscountToken next discount token
   **/
  event DiscountTokenUpdated(
    address indexed previousDiscountToken,
    address indexed nextDiscountToken
  );

  /**
   * @dev Emitted when the discount lock period is updated
   * @param previousDiscountLockPeriod previous DiscountLockPeriod
   * @param nextDiscountLockPeriod next DiscountLockPeriod
   **/
  event DiscountLockPeriodUpdated(
    uint256 indexed previousDiscountLockPeriod,
    uint256 indexed nextDiscountLockPeriod
  );

  /**
   * @dev Emitted when a user's discount or rebalanceTimestamp is updated
   * @param user The address of the user
   * @param discountPercent The discount percent of the user
   * @param rebalanceTimestamp Timestamp when a users locked discount can be rebalanced
   **/
  event DiscountPercentLocked(
    address indexed user,
    uint256 indexed discountPercent,
    uint256 indexed rebalanceTimestamp
  );

  /**
   * @dev Sets a reference to the GhoAToken contract
   * @dev Only callable by the pool admin
   * @param aToken GhoAToken contract
   **/
  function setAToken(address aToken) external;

  /**
   * @dev Returns the address of the GhoAToken contract
   **/
  function getAToken() external view returns (address);

  /**
   * @dev Updates the Discount Rate Strategy
   * @dev Only callable by the pool admin
   * @param discountRateStrategy address of discount rate strategy contract
   **/
  function updateDiscountRateStrategy(address discountRateStrategy) external;

  /**
   * @dev Returns the address of the Discount Rate Strategy
   * @return address of DiscountRateStrategy
   **/
  function getDiscountRateStrategy() external view returns (address);

  /**
   * @dev Updates the Discount Token
   * @dev Only callable by the pool admin
   * @param discountToken address of discount token contract
   **/
  function updateDiscountToken(address discountToken) external;

  /**
   * @dev Returns the address of the Discount Token
   * @return address of Discount Token
   **/
  function getDiscountToken() external view returns (address);

  /**
   * @dev updates the discount when discount token is transferred
   * @dev Only callable by discount token
   * @param sender address of sender
   * @param recipient address of recipient
   * @param senderDiscountTokenBalance sender discount token balance
   * @param recipientDiscountTokenBalance recipient discount token balance
   * @param amount amount of discount token being transferred
   **/
  function updateDiscountDistribution(
    address sender,
    address recipient,
    uint256 senderDiscountTokenBalance,
    uint256 recipientDiscountTokenBalance,
    uint256 amount
  ) external;

  /**
   * @dev Returns the discount percent being applied to the borrow interests of the user
   * @param user The address of the user
   * @return The discount percent (expressed in bps)
   */
  function getDiscountPercent(address user) external view returns (uint256);

  /*
   * @dev Returns the amount of interests accumulated by the user
   * @param user The address of the user
   * @return The amount of interests accumulated by the user
   */
  function getBalanceFromInterest(address user) external view returns (uint256);

  /**
   * @dev Decrease the amount of interests accumulated by the user
   * @param user The address of the user
   * @param amount The value to be decrease
   */
  function decreaseBalanceFromInterest(address user, uint256 amount) external;

  /**
   * @dev Rebalance the discount percent of a user if they are past their rebalance timestamp
   * @param user The address of the user
   */
  function rebalanceUserDiscountPercent(address user) external;

  /**
   * @dev Updates the period of time a users is entitled to a discount before they can be rebalanced
   * @param newLockPeriod The new value
   */
  function updateDiscountLockPeriod(uint256 newLockPeriod) external;

  /**
   * @dev Returns period of time a user will be entitled to a discount once their discount rate is set
   * @return The discount refresh threshold, expressed in ray
   */
  function getDiscountLockPeriod() external view returns (uint256);

  /**
   * @dev Returns the timestamp at which a user's discount percent can be rebalanced
   * @param user address of the user's rebalance timestamp being requested
   * @return The time when a users discount can be rebalanced
   */
  function getUserRebalanceTimestamp(address user) external view returns (uint256);
}
