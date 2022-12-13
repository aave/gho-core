// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';

contract MockFlashBorrower is IERC3156FlashBorrower {
  enum Action {
    NORMAL,
    OTHER
  }

  IERC3156FlashLender private _lender;

  bool allowRepayment;

  constructor(IERC3156FlashLender lender) {
    _lender = lender;
    allowRepayment = true;
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
    return keccak256('ERC3156FlashBorrower.onFlashLoan');
  }

  /// @dev Initiate a flash loan
  function flashBorrow(address token, uint256 amount) public {
    bytes memory data = abi.encode(Action.NORMAL);

    if (allowRepayment) {
      uint256 allowance = IERC20(token).allowance(address(this), address(_lender));
      uint256 fee = _lender.flashFee(token, amount);
      uint256 repayment = amount + fee;
      IERC20(token).approve(address(_lender), allowance + repayment);
    }

    _lender.flashLoan(this, token, amount, data);
  }

  function setAllowRepayment(bool active) public {
    allowRepayment = active;
  }
}
