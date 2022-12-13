// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IGhoFlashMinter} from '../interfaces/IGhoFlashMinter.sol';

contract MockFlashBorrower is IERC3156FlashBorrower {
  enum Action {
    NORMAL,
    OTHER
  }

  IGhoFlashMinter private _flashMinter;

  bool allowRepayment;

  constructor(IGhoFlashMinter flashMinter) {
    _flashMinter = flashMinter;
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
    require(msg.sender == address(_flashMinter), 'FlashBorrower: Untrusted lender');
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
      uint256 allowance = IERC20(token).allowance(address(this), address(_flashMinter));
      uint256 fee = _flashMinter.flashFee(amount);
      uint256 repayment = amount + fee;
      IERC20(token).approve(address(_flashMinter), allowance + repayment);
    }

    _flashMinter.flashLoan(this, amount, data);
  }

  function setAllowRepayment(bool active) public {
    allowRepayment = active;
  }
}
