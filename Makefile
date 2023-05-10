test       :; forge test -vvv

# install lcov via  $ apt install lcov or $ brew install lcov to be able to ignore tests and mock files
coverage   :; forge coverage --report lcov && lcov --remove ./lcov.info -o ./lcov.info.pruned 'src/contracts/foundry-test/*' 'src/contracts/facilitators/flashMinter/mocks/*' src/contracts/facilitators/aave/mocks/* && mv lcov.info.pruned lcov.info && genhtml ./lcov.info -o report --branch-coverage
