// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IGhoFlashReceiver} from '../interfaces/IGhoFlashReceiver.sol';
import {IGhoFlashMinter} from '../interfaces/IGhoFlashMinter.sol';

contract MockGhoFlashBorrower is IGhoFlashReceiver {
  using PercentageMath for uint256;

  enum Action {
    NORMAL,
    OTHER
  }

  IGhoFlashMinter private _lender;

  bool allowRepayment;

  constructor(IGhoFlashMinter lender) {
    _lender = lender;
    allowRepayment = true;
  }

  /// @dev Gho Flash loan callback
  function onFlashLoan(
    address initiator,
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
    return keccak256('GhoFlashMinter.onFlashLoan');
  }

  /// @dev Initiate a flash loan
  function flashBorrow(address token, uint256 amount) public {
    bytes memory data = abi.encode(Action.NORMAL);

    if (allowRepayment) {
      uint256 allowance = IERC20(token).allowance(address(this), address(_lender));
      uint256 feePercent = _lender.getFee();
      uint256 fee = amount.percentMul(feePercent);
      uint256 repayment = amount + fee;
      IERC20(token).approve(address(_lender), allowance + repayment);
    }

    _lender.ghoFlashLoan(this, amount, data);
  }

  function setAllowRepayment(bool active) public {
    allowRepayment = active;
  }
}
