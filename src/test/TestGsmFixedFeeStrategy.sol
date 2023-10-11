// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmFixedFeeStrategy is TestGhoBase {
  function testRevertHundredPercentFee() public {
    vm.expectRevert('INVALID_BUY_FEE');
    FixedFeeStrategy feeStrategy = new FixedFeeStrategy(10000, DEFAULT_GSM_SELL_FEE);

    vm.expectRevert('INVALID_SELL_FEE');
    feeStrategy = new FixedFeeStrategy(DEFAULT_GSM_BUY_FEE, 10000);
  }

  function testZeroBuyFee() public {
    FixedFeeStrategy feeStrategy = new FixedFeeStrategy(0, DEFAULT_GSM_SELL_FEE);
    uint256 fee = feeStrategy.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    assertEq(fee, 0, 'Unexpected non-zero fee');
    assertEq(
      feeStrategy.getGrossAmountFromTotalBought(DEFAULT_GSM_GHO_AMOUNT + fee),
      DEFAULT_GSM_GHO_AMOUNT
    );
  }

  function testZeroSellFee() public {
    FixedFeeStrategy feeStrategy = new FixedFeeStrategy(DEFAULT_GSM_BUY_FEE, 0);
    uint256 fee = feeStrategy.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    assertEq(fee, 0, 'Unexpected non-zero fee');
    assertEq(
      feeStrategy.getGrossAmountFromTotalSold(DEFAULT_GSM_GHO_AMOUNT + fee),
      DEFAULT_GSM_GHO_AMOUNT
    );
  }

  function testRevertBothFeesZero() public {
    vm.expectRevert('MUST_HAVE_ONE_NONZERO_FEE');
    new FixedFeeStrategy(0, 0);
  }
}
