if (($# > 0))
then
certoraRun certora/harness/GhoDiscountRateStrategyHarness.sol:GhoDiscountRateStrategyHarness \
    --verify GhoDiscountRateStrategyHarness:certora/specs/ghoDiscountRateStrategy.spec \
    --solc solc8.10 \
    --loop_iter 2 \
    --optimistic_loop \
    --settings -t=500,-mediumTimeout=20,-depth=10 \
    --cloud \
    --rules "${@}" \
    --msg "GhoDiscountRateStrategy, rules ${@}."
else
certoraRun certora/harness/GhoDiscountRateStrategyHarness.sol:GhoDiscountRateStrategyHarness \
    --verify GhoDiscountRateStrategyHarness:certora/specs/ghoDiscountRateStrategy.spec \
    --solc solc8.10 \
    --loop_iter 2 \
    --optimistic_loop \
    --settings -t=500,-mediumTimeout=20,-depth=10 \
    --cloud \
    --msg "GhoDiscountRateStrategy, all rules."
fi
