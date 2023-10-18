#!/bin/sh

if (($# > 0))
then
certoraRun certora/harness/GhoTokenHarness.sol:GhoTokenHarness certora/munged/contracts/gho/GhoToken.sol \
    --verify GhoTokenHarness:certora/specs/ghoToken.spec \
    --solc solc8.10 \
    --loop_iter 3 \
    --optimistic_loop \
    --cloud \
    --rules "${@}" \
    --msg "GhoToken, rules ${@}"
else
certoraRun certora/harness/GhoTokenHarness.sol:GhoTokenHarness certora/munged/contracts/gho/GhoToken.sol \
    --verify GhoTokenHarness:certora/specs/ghoToken.spec \
    --solc solc8.10 \
    --loop_iter 3 \
    --optimistic_loop \
    --cloud \
    --msg "GhoToken, all rules."
fi