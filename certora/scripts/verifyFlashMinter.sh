if (($# > 0))
then
certoraRun certora/munged/contracts/facilitators/flashMinter/GhoFlashMinter.sol:GhoFlashMinter \
           certora/munged/contracts/facilitators/aave/tokens/GhoAToken.sol:GhoAToken \
           certora/munged/contracts/gho/GhoToken.sol \
           certora/harness/MockFlashBorrower.sol \
    --verify GhoFlashMinter:certora/specs/flashMinter.spec \
    --link GhoFlashMinter:GHO_TOKEN=GhoToken \
           MockFlashBorrower:minter=GhoFlashMinter \
           MockFlashBorrower:Gho=GhoToken \
           MockFlashBorrower:AGho=GhoAToken \
    --solc solc8.10 \
    --optimistic_loop \
    --cloud \
    --settings -contractRecursionLimit=1 \
    --rules "${@}"
    --msg "flashMinter check, rules ${@}"
else
certoraRun certora/munged/contracts/facilitators/flashMinter/GhoFlashMinter.sol:GhoFlashMinter \
           certora/munged/contracts/facilitators/aave/tokens/GhoAToken.sol:GhoAToken \
           certora/munged/contracts/gho/GhoToken.sol \
           certora/harness/MockFlashBorrower.sol \
    --verify GhoFlashMinter:certora/specs/flashMinter.spec \
    --link GhoFlashMinter:GHO_TOKEN=GhoToken \
           MockFlashBorrower:minter=GhoFlashMinter \
           MockFlashBorrower:Gho=GhoToken \
           MockFlashBorrower:AGho=GhoAToken \
    --solc solc8.10 \
    --optimistic_loop \
    --cloud \
    --settings -contractRecursionLimit=1 \
    --msg "flashMinter check, all rules"
fi


