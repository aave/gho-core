
#!/bin/bash

# @dev
# This bash script creates coverage reports via Hardhat and Foundry
# and then merges them, removing uninteresting files

npm run hardhat coverage
forge coverage --report lcov

# sed -i -e 's/\/.*gho-core.//g' coverage/lcov.info
sed -i -e '/^FN\|FNDA:/s/,[^.]*\./,/g' lcov.info



lcov \
    --rc lcov_branch_coverage=1 \
    --add-tracefile coverage/lcov.info \
    --add-tracefile lcov.info \
    --output-file merged-lcov.info

lcov \
    --rc lcov_branch_coverage=1 \
    --remove merged-lcov.info \
    --output-file combined-lcov.info \
    "*node_modules*" "*test*" "*mock*" "*script*"

rm merged-lcov.info

lcov \
    --rc lcov_branch_coverage=1 \
    --list combined-lcov.info

genhtml ./combined-lcov.info -o report --branch-coverage