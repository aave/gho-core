#!/bin/sh

certoraRun certora/harness/ghoVariableDebtTokenHarness.sol:GhoVariableDebtTokenHarness \
    certora/harness/DummyPool.sol \
    certora/harness/DummyERC20WithTimedBalanceOf.sol \
    certora/munged/contracts/facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol \
    certora/harness/DummyERC20A.sol certora/harness/DummyERC20B.sol \
    --verify GhoVariableDebtTokenHarness:certora/specs/ghoVariableDebtToken.spec \
    --link GhoVariableDebtTokenHarness:_discountRateStrategy=GhoDiscountRateStrategy \
    --link GhoVariableDebtTokenHarness:_discountToken=DummyERC20WithTimedBalanceOf \
    --link GhoVariableDebtTokenHarness:POOL=DummyPool \
    --loop_iter 2 \
    --solc solc8.10 \
    --optimistic_loop \
    --cloud \
    --rules BurnFullResolveZeroV2 \
    --msg "GhoVariableDebtToken, rules BurnFullResolveZeroV2 prev index GE ray"
