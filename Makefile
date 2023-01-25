sinclude .env

# local network
start_network:
	@npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY}

# gho_deploy
gho_setup:
	npm run hardhat gho-testnet-setup
gho_local_setup::
	npm run hardhat gho-testnet-setup -- --network localhost

# hardhat
hardhat_compile:
	npm run compile
hardhat_test:
	npm run test
hardhat_test_all:
	npm run test-all
hardhat_test_unit:
	npm run test-unit
hardhat_local_test:
	npm run test -- --network localhost
hardhat_clean:
	npm run clean

# forge
forge_build:
	forge build
forge_test:
	forge test --contracts src/contracts/foundry_tests --lib-paths node_modules
forge_test_vv:
	forge test --contracts src/contracts/foundry_tests --lib-paths node_modules -vv
forge_test_vvv:
	forge test --contracts src/contracts/foundry_tests --lib-paths node_modules -vvv
forge_test_vvvv:
	forge test --contracts src/contracts/foundry_tests --lib-paths node_modules -vvvv
forge_local_test:
	@forge test --contracts src/contracts/foundry_tests --lib-paths node_modules -f http://127.0.0.1:8545/
forge_local_test_vv:
	@forge test --contracts src/contracts/foundry_tests --lib-paths node_modules -f http://127.0.0.1:8545/ -vv
forge_local_test_vvv:
	@forge test --contracts src/contracts/foundry_tests --lib-paths node_modules -f http://127.0.0.1:8545/ -vvv
forge_local_test_vvvv:
	@forge test --contracts src/contracts/foundry_tests --lib-paths node_modules -f http://127.0.0.1:8545/ -vvvv

# formatting
check_prettier:
	npx prettier --check "src/**/*.sol" --config ./.prettierrc
write_prettier:
	npx prettier --write "src/**/*.sol" --config ./.prettierrc
