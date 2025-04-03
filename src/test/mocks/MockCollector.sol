// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';

/**
 * @dev Mock contract to test GHO Remote Vault, not to be used in production.
 */
contract MockCollector is Initializable, AccessControl {
  address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  bytes32 public constant FUNDS_ADMIN_ROLE = 'FUNDS_ADMIN';
  uint256 public ghoOutstanding;

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

  function transferGho(address recipient, uint256 amount) external onlyFundsAdmin {
    ghoOutstanding += amount;
    IERC20(GHO).transfer(recipient, amount);
  }

  function payBackGho(uint256 amount) external onlyFundsAdmin {
    ghoOutstanding -= amount;
    IERC20(GHO).transferFrom(msg.sender, address(this), amount);
  }

  function bridgeGho(uint256 amount) external onlyFundsAdmin {
    // Intentionally left bank
  }

  function _onlyFundsAdmin() internal view returns (bool) {
    return hasRole(FUNDS_ADMIN_ROLE, msg.sender);
  }
}
