# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# Deploy GHO Stewards V2
deploy-gho-stewards :; forge script src/script/DeployGhoStewardsV2.s.sol:DeployGhoStewardsV2 --rpc-url mainnet --broadcast --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER}  --etherscan-api-key ${ETHERSCAN_API_KEY_MAINNET} --gas-estimate-multiplier 125 --verify -vvvv