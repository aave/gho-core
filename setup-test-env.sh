
#!/bin/bash

# @dev
# This bash script setups the needed artifacts to use
# the @aave/deploy-v3 package as source of deployment
# scripts for testing or coverage purposes.
#
# A separate  artifacts directory was created 
# due at running tests all external artifacts
# located at /artifacts are deleted,  causing
# the deploy library to not find the external
# artifacts. 

echo "[BASH] Setting up testnet enviroment"

if [ ! "$COVERAGE" = true ]; then
    # remove hardhat and artifacts cache
    npm run ci:clean

    # compile @aave/core-v3 contracts
    npm run compile
else
    echo "[BASH] Skipping compilation to keep coverage artifacts"
fi

# Copy artifacts into separate directory to allow
# the hardhat-deploy library load all artifacts without duplicates 
mkdir -p temp-artifacts
cp -r artifacts/@openzeppelin temp-artifacts/
cp -r artifacts/build-info temp-artifacts/
cp -r artifacts/src temp-artifacts/

# Import external @aave/safety-module artifacts
mkdir -p temp-artifacts/safety-module
cp -r 'node_modules/@aave/deploy-v3/artifacts/@aave/safety-module/contracts/stake' temp-artifacts/safety-module
cp -r 'node_modules/@aave/deploy-v3/artifacts/@aave/safety-module/contracts/proposals' temp-artifacts/safety-module

# Import external @aave/periphery artifacts
mkdir -p temp-artifacts/periphery
cp -r node_modules/@aave/periphery-v3/artifacts/contracts/* temp-artifacts/periphery

# Import external @aave/core artifacts
mkdir -p temp-artifacts/core-v3
cp -r node_modules/@aave/core-v3/artifacts/contracts/* temp-artifacts/core-v3

# Import external @aave/deploy artifacts
mkdir -p temp-artifacts/deploy
cp -r node_modules/@aave/deploy-v3/artifacts/contracts/* temp-artifacts/deploy

# Export MARKET_NAME variable to use Aave market as testnet deployment setup
export MARKET_NAME="Test"

# Deploy stkAave in local
export ENABLE_REWARDS="true"
echo "[BASH] Testnet enviroment ready"