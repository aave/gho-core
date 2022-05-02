// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

interface IAnteiVariableDebtToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @param aToken Antei aToken contract
   **/
  event ATokenSet(address indexed aToken);

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
