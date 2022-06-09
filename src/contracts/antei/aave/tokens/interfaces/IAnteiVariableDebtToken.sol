// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

interface IAnteiVariableDebtToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @param aToken Antei aToken contract
   **/
  event ATokenSet(address indexed aToken);

  /**
   * @dev Emitted when the address of the discount token is set
   * @param previousDiscountToken Address of the previous discount token
   * @param updatedDiscountToken Address of the updated discount token
   **/
  event DiscountTokenSet(
    address indexed previousDiscountToken,
    address indexed updatedDiscountToken
  );

  /**
   * @dev Emitted when the discount rate is set
   * @param previousDiscountRate The previous discount rate
   * @param updatedDiscountRate The updated discount rate
   */
  event DiscountRateSet(uint256 indexed previousDiscountRate, uint256 indexed updatedDiscountRate);

  /**
   * @dev Emitted when the max discount rate is set
   * @param previousMaxDiscountRate The previous max discount rate
   * @param updatedMaxDiscountRate The updated max discount rate
   */
  event MaxDiscountRateSet(uint256 indexed previousMaxDiscountRate, uint256 updatedMaxDiscountRate);

  /**
   * @dev Emitted when a users interest balance is paid down
   * @param user Address of user
   * @param previousBalanceFromInterest User's balance from interest before repayment
   * @param updatedBalanceFromInterest User's balance from interest after repayment
   **/
  event BalanceFromInterestReduced(
    address indexed user,
    uint256 indexed previousBalanceFromInterest,
    uint256 indexed updatedBalanceFromInterest
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
   * @dev Sets a reference to the discount token contract
   * a users discount will be dependent on their balance of this token
   * @dev Only callable by the pool admin
   * @param discountToken Address of the discount token
   **/
  function setDiscountToken(address discountToken) external;

  /**
   * @dev Returns the address of the discount token
   **/
  function getDiscountToken() external view returns (address);

  /**
   * @dev Set the discount rate applied to interest - two decimals (10000 = 100.00)
   * @dev Max allowed value is 10000
   * @dev Only callable by the pool admin
   * @param discountRate Discount rate applied to interest
   **/
  function setDiscountRate(uint256 discountRate) external;

  /**
   * @dev Returns the current discount rate
   **/
  function getDiscountRate() external view returns (uint256);

  /**
   * @dev Set the maximum discount rate - two decimals (10000 = 100.00)
   * @dev Max allowed value is 10000
   * @dev User discounts will be capped per this max discount rate
   * @dev Only callable by the pool admin
   * @param maxDiscountRate Max discount rate users can earn
   **/
  function setMaxDiscountRate(uint256 maxDiscountRate) external;

  /**
   * @dev Returns the current max discount rate
   **/
  function getMaxDiscountRate() external view returns (uint256);

  /**
   * @dev Gets a users balance from interest
   * @param user User's address
   * @return Users balance that comes from interest owed
   **/
  function getBalanceFromInterest(address user) external view returns (uint256);

  /**
   * @dev Decrease the amount of interest a user owes after they repay debt
   * @dev Only callable by the AToken
   * @param user address of user to decrease their balance from interest
   * @param amount amount to decrease the users balance from interest
   **/
  function decreaseBalanceFromInterest(address user, uint256 amount) external;
}
