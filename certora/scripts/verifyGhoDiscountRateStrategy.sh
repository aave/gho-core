if (($# > 0))
then
certoraRun certora/harness/GhoDiscountRateStrategyHarness.sol:GhoDiscountRateStrategyHarness \
    --verify GhoDiscountRateStrategyHarness:certora/specs/ghoDiscountRateStrategy.spec \
    --solc solc8.10 \
    --loop_iter 2 \
    --optimistic_loop \
    --prover_args "-mediumTimeout 20 -depth 10" \
    --smt_timeout 500 \
    --rules "${@}" \
    --msg "GhoDiscountRateStrategy, rules ${@}."
else
certoraRun certora/harness/GhoDiscountRateStrategyHarness.sol:GhoDiscountRateStrategyHarness \
    --verify GhoDiscountRateStrategyHarness:certora/specs/ghoDiscountRateStrategy.spec \
    --solc solc8.10 \
    --loop_iter 2 \
    --optimistic_loop \
    --prover_args "-mediumTimeout 20 -depth 10" \
    --smt_timeout 500 \
    --msg "GhoDiscountRateStrategy, all rules."
fi
