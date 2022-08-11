certoraRun src/contracts/gho/GhoToken.sol:GhoToken \
    --verify GhoToken:certora/specs/complexity.spec \
    --solc solc8.15 \
    --optimistic_loop \
    --staging \
    --msg "GhoToken complexity check"

certoraRun src/contracts/facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol:GhoDiscountRateStrategy \
    --verify GhoDiscountRateStrategy:certora/specs/complexity.spec \
    --solc solc8.10 \
    --optimistic_loop \
    --staging \
    --msg "GhoDiscountRateStrategy complexity check"

certoraRun src/contracts/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol:GhoInterestRateStrategy \
    --verify GhoInterestRateStrategy:certora/specs/complexity.spec \
    --solc solc8.10 \
    --optimistic_loop \
    --staging \
    --msg "GhoInterestRateStrategy complexity check"

certoraRun src/contracts/facilitators/aave/tokens/GhoAToken.sol:GhoAToken \
    --verify GhoAToken:certora/specs/complexity.spec \
    --solc solc8.10 \
    --optimistic_loop \
    --staging \
    --msg "GhoAToken complexity check"

certoraRun src/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol:GhoVariableDebtToken \
    --verify GhoVariableDebtToken:certora/specs/complexity.spec \
    --solc solc8.10 \
    --optimistic_loop \
    --staging \
    --msg "GhoVariableDebtToken complexity check"

certoraRun src/contracts/facilitators/aave/oracle/GhoOracle.sol:GhoOracle \
    --verify GhoOracle:certora/specs/complexity.spec \
    --solc solc8.10 \
    --optimistic_loop \
    --staging \
    --msg "GhoOracle complexity check"

certoraRun src/contracts/facilitators/aave/stkAaveUpgrade/StakedAaveV2Rev4.sol:StakedTokenV2Rev4 \
    --verify StakedTokenV2Rev4:certora/specs/complexity.spec \
    --solc solc7.5 \
    --optimistic_loop \
    --staging \
    --msg "StakedAaveV2Rev4 complexity check"
