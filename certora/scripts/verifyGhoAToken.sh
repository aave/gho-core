#!/bin/sh

if (($# > 0))
then
certoraRun certora/munged/contracts/facilitators/aave/tokens/GhoAToken.sol \
          certora/munged/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol \
          certora/munged/contracts/gho/GhoToken.sol \
          certora/harness/GhoTokenHarness.sol \
          certora/harness/DummyERC20A.sol certora/harness/DummyERC20B.sol \
    --verify GhoAToken:certora/specs/ghoAToken.spec \
    --link GhoAToken:_ghoVariableDebtToken=GhoVariableDebtToken \
    --link GhoAToken:_underlyingAsset=GhoTokenHarness \
    --link GhoVariableDebtToken:_ghoAToken=GhoAToken \
    --solc solc8.10 \
    --optimistic_loop \
    --rules "${@}" \
    --msg "GhoAToken, rules ${@}"
else
certoraRun certora/munged/contracts/facilitators/aave/tokens/GhoAToken.sol \
          certora/munged/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol \
          certora/munged/contracts/gho/GhoToken.sol \
          certora/harness/GhoTokenHarness.sol \
          certora/harness/DummyERC20A.sol certora/harness/DummyERC20B.sol \
    --verify GhoAToken:certora/specs/ghoAToken.spec \
    --link GhoAToken:_ghoVariableDebtToken=GhoVariableDebtToken \
    --link GhoAToken:_underlyingAsset=GhoTokenHarness \
    --link GhoVariableDebtToken:_ghoAToken=GhoAToken \
    --solc solc8.10 \
    --optimistic_loop \
    --send_only \
    --msg "GhoAToken, all rules"
fi
