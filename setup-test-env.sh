
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

# Copy artifacts into /artifacts directory to load all artifacts and preventing duplicates 

# Import external @aave/safety-module artifacts
mkdir -p artifacts/@aave/safety-module/contracts
mkdir -p artifacts/@aave/safety-module/build-info

cp -r node_modules/@aave/deploy-v3/artifacts/@aave/safety-module/contracts/stake  artifacts/@aave/safety-module/contracts
cp -r node_modules/@aave/deploy-v3/artifacts/@aave/safety-module/contracts/proposals  artifacts/@aave/safety-module/contracts
cp -r node_modules/@aave/deploy-v3/artifacts/build-info/*  artifacts/build-info

# Import external @aave/core artifacts
mkdir -p artifacts/contracts

cp -r node_modules/@aave/core-v3/artifacts/contracts/* artifacts/contracts
cp -r node_modules/@aave/core-v3/artifacts/build-info/* artifacts/build-info


# Import external @aave/periphery artifacts
cp -r node_modules/@aave/periphery-v3/artifacts/contracts/* artifacts/contracts
cp -r node_modules/@aave/periphery-v3/artifacts/build-info/*   artifacts/build-info


# Export MARKET_NAME variable to use Aave market as testnet deployment setup
export MARKET_NAME="Test"

# Deploy stkAave in local
export ENABLE_REWARDS="true"
echo "[BASH] Testnet environment ready"