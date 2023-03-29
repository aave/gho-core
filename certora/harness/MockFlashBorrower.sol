// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IGhoFlashMinter} from '../munged/contracts/facilitators/flashMinter/interfaces/IGhoFlashMinter.sol';
import {IGhoToken} from '../munged/contracts/gho/interfaces/IGhoToken.sol';
import {IGhoAToken} from '../munged/contracts/facilitators/aave/tokens/interfaces/IGhoAToken.sol';

contract MockFlashBorrower is IERC3156FlashBorrower {
  enum Action {
    FLASH_LOAN,
    DISTRIBUTE_FEES,
    UPDATE_FEES,
    UPDATE_TREASURY,
    MINT,
    BURN,
    ADD_FACILITATOR,
    REMOVE_FACILITATOR,
    SET_FACILITATOR,
    APPROVE,
    TRANSFER,
    TRANSFER_FROM,
    TRANSFER_UNDERLYING_TO,
    HANDLE_REPAYMENT,
    ATOKEN_DISTRIBUTE_FEES,
    RESCUE_TOKENS,
    SET_VAR_DEBT_TOKEN,
    ATOKEN_UPDATE_TREASURY,
    OTHER
  }

  struct Facilitator {
    uint128 bucketCapacity;
    uint128 bucketLevel;
    string label;
  }

  Action public action;
  uint8 public counter;
  uint8 public repeat_on_count;
  IGhoFlashMinter public minter;
  IGhoToken public Gho;
  IGhoAToken public AGho;
  address public _transferTo;

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
    counter++;
    if (action == Action.FLASH_LOAN && counter < repeat_on_count) {
      uint256 amount_reenter;
      bytes calldata data_reenter;
      minter.flashLoan(IERC3156FlashBorrower(address(this)), token, amount, data);
    } else if (action == Action.DISTRIBUTE_FEES) {
      minter.distributeFeesToTreasury();
    } else if (action == Action.UPDATE_FEES) {
      uint256 new_fee;
      minter.updateFee(new_fee);
    } else if (action == Action.UPDATE_TREASURY) {
      address newGhoTreasury;
      minter.updateGhoTreasury(newGhoTreasury);
    } else if (action == Action.MINT) {
      address account;
      uint256 amt;
      Gho.mint(account, amt);
    } else if (action == Action.BURN) {
      uint256 amt;
      Gho.burn(amt);
      // } else if (action == Action.ADD_FACILITATOR) {
      //     address facilitatorAddress; Facilitator memory facilitatorConfig;
      //     Gho.addFacilitator(facilitatorAddress, facilitatorConfig);
    } else if (action == Action.REMOVE_FACILITATOR) {
      address facilitatorAddress;
      Gho.removeFacilitator(facilitatorAddress);
    } else if (action == Action.SET_FACILITATOR) {
      address facilitator;
      uint128 newCapacity;
      Gho.setFacilitatorBucketCapacity(facilitator, newCapacity);
    } else if (action == Action.APPROVE) {
      address spender;
      uint256 amt;
      AGho.approve(spender, amt);
    } else if (action == Action.TRANSFER) {
      uint256 amt;
      AGho.transfer(_transferTo, amt);
    } else if (action == Action.TRANSFER_FROM) {
      address from;
      uint256 amt;
      AGho.transferFrom(from, _transferTo, amt);
    } else if (action == Action.TRANSFER_UNDERLYING_TO) {
      address target;
      uint256 amt;
      AGho.transferUnderlyingTo(target, amt);
    } else if (action == Action.HANDLE_REPAYMENT) {
      address user;
      address onBehalfOf;
      uint256 amt;
      AGho.handleRepayment(user, onBehalfOf, amt);
    } else if (action == Action.ATOKEN_DISTRIBUTE_FEES) {
      AGho.distributeFeesToTreasury();
    } else if (action == Action.RESCUE_TOKENS) {
      address token;
      address to;
      uint256 amt;
      AGho.rescueTokens(token, to, amt);
    } else if (action == Action.SET_VAR_DEBT_TOKEN) {
      address ghoVariableDebtToken;
      AGho.setVariableDebtToken(ghoVariableDebtToken);
    } else if (action == Action.ATOKEN_UPDATE_TREASURY) {
      address newGhoTreasury;
      AGho.updateGhoTreasury(newGhoTreasury);
    } else if (action == Action.OTHER) {
      require(true);
    }
    return keccak256('ERC3156FlashBorrower.onFlashLoan');
  }

  /// @dev Initiate a flash loan
  function flashBorrow(address token, uint256 amount) public {
    bytes memory data = abi.encode(Action.FLASH_LOAN);

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
