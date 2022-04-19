ifneq (,$(wildcard ./.env))
    include .env
    export
endif

build:
	forge build

test:
	forge test
test_v:
	forge test -v
test_vv:
	forge test -vv
test_vvv:
	forge test -vvv
test_vvvv:
	forge test -vvvv

fork_test:
	@forge test -f https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY}
fork_test_v:
	@forge test -f https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY} -v
fork_test_vv:
	@forge test -f https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY} -vv
fork_test_vvv:
	@forge test -f https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY} -vvv
fork_test_vvvv:
	@forge test -f https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY} -vvvv

check_prettier:
	npx prettier --check "src/**/*.sol" --config ./.prettierrc
write_prettier:
	npx prettier --write "src/**/*.sol" --config ./.prettierrc