// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IVariableDebtToken} from './IVariableDebtToken.sol';

interface IAnteiVariableDebtToken is IVariableDebtToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @param aToken Antei aToken contract
   **/
  event ATokenSet(address indexed aToken);

  /**
   * @dev Emitted when the AnteiDiscountRateStrategy is updated
   * @param previousDiscountRateStrategy previous AnteiDiscountRateStrategy
   * @param nextDiscountRateStrategy next AnteiDiscountRateStrategy
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
   * @dev Emitted when the Discount Percent of a user is updated
   * @param user The address of the user which discount percent is updated
   * @param previousDiscountPercent The previous discount percent of the user
   * @param nextDiscountPercent The next discount percent of the user
   **/
  event DiscountPercentUpdated(
    address indexed user,
    uint256 indexed previousDiscountPercent,
    uint256 indexed nextDiscountPercent
  );

  /**
   * @dev Emitted when the discount token distribution is updated
   * @param sender address of sender
   * @param recipient address of recipient
   * @param senderDiscountTokenBalance sender discount token balance
   * @param recipientDiscountTokenBalance recipient discount token balance
   * @param amount amount of discount token being transferred
   **/
  event DiscountDistributionUpdated(
    address indexed sender,
    address indexed recipient,
    uint256 senderDiscountTokenBalance,
    uint256 recipientDiscountTokenBalance,
    uint256 amount
  );

  /**
   * @dev Sets a reference to the Antei AToken contract
   * @dev Only callable by the pool admin
   * @param aToken Antei aToken contract
   **/
  function setAToken(address aToken) external;

  /**
   * @dev Returns the address of the Antei AToken contract
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

  /**
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
}
