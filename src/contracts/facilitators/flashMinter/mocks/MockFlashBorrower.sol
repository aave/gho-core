// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';

contract MockFlashBorrower is IERC3156FlashBorrower {
  enum Action {
    NORMAL,
    OTHER
  }

  IERC3156FlashLender private _lender;

  bool private _allowRepayment;
  bool private _allowCallback;

  constructor(IERC3156FlashLender lender) {
    _lender = lender;
    _allowRepayment = true;
    _allowCallback = true;
  }

  /// @dev ERC-3156 Flash loan callback
  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    require(msg.sender == address(_lender), 'FlashBorrower: Untrusted lender');
    require(initiator == address(this), 'FlashBorrower: Untrusted loan initiator');
    Action action = abi.decode(data, (Action));
    if (action == Action.NORMAL) {
      // do one thing
    } else if (action == Action.OTHER) {
      // do another
    }

    // Repayment
    if (_allowRepayment) {
      IERC20(token).approve(address(_lender), amount + fee);
    }
    return _allowCallback ? keccak256('ERC3156FlashBorrower.onFlashLoan') : keccak256('arbitrary');
  }

  /// @dev Initiate a flash loan
  function flashBorrow(address token, uint256 amount) public {
    bytes memory data = abi.encode(Action.NORMAL);

    _lender.flashLoan(this, token, amount, data);
  }

  function setAllowRepayment(bool active) public {
    _allowRepayment = active;
  }

  function setAllowCallback(bool active) public {
    _allowCallback = active;
  }
}
