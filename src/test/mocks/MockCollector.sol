// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';

/**
 * @dev Mock contract to test upgrades, not to be used in production.
 */
contract MockCollector is Initializable, AccessControl {
  bytes32 public constant FUNDS_ADMIN_ROLE = 'FUNDS_ADMIN';

  /**
   * @dev Throws if the caller does not have the FUNDS_ADMIN role
   */
  modifier onlyFundsAdmin() {
    require(_onlyFundsAdmin(), 'ONLY_FUNDS_ADMIN');
    _;
  }

  /**
   * @dev Constructor
   */
  constructor() {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /**
   * @dev Initializer
   */
  function initialize() public reinitializer(2) {
    // Intentionally left bank
  }

  function approve(IERC20 token, address recipient, uint256 amount) external onlyFundsAdmin {
    token.approve(recipient, amount);
  }

  function transfer(IERC20 token, address recipient, uint256 amount) external onlyFundsAdmin {
    token.transfer(recipient, amount);
  }

  function _onlyFundsAdmin() internal view returns (bool) {
    return hasRole(FUNDS_ADMIN_ROLE, msg.sender);
  }
}
