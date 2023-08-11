// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGSMFixedFeeStrategy is TestGhoBase {
  function testRevertMoreThanHundredPercentFee() public {
    vm.expectRevert('INVALID_BUY_FEE');
    FixedFeeStrategy feeStrategy = new FixedFeeStrategy(10001, DEFAULT_GSM_SELL_FEE);

    vm.expectRevert('INVALID_SELL_FEE');
    feeStrategy = new FixedFeeStrategy(DEFAULT_GSM_BUY_FEE, 10001);
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

  function testMaxBuyFee() public {
    FixedFeeStrategy feeStrategy = new FixedFeeStrategy(10000, DEFAULT_GSM_SELL_FEE);
    uint256 fee = feeStrategy.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    assertEq(fee, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected fee less than 100%');
    assertEq(
      feeStrategy.getGrossAmountFromTotalBought(DEFAULT_GSM_GHO_AMOUNT + fee),
      DEFAULT_GSM_GHO_AMOUNT
    );
  }

  function testMaxSellFee() public {
    FixedFeeStrategy feeStrategy = new FixedFeeStrategy(DEFAULT_GSM_BUY_FEE, 10000);
    uint256 fee = feeStrategy.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    assertEq(fee, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected fee less than 100%');
    assertEq(
      feeStrategy.getGrossAmountFromTotalSold(DEFAULT_GSM_GHO_AMOUNT + fee),
      DEFAULT_GSM_GHO_AMOUNT
    );
  }
}
