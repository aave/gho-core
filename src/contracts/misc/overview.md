This document describes the roles and responsibilities of the Gho Stewards.

## Gho Steward Contracts

These contracts each control different parameters related to GHO, GSM, and CCIP. They allow the Aave DAO and an approved Risk Council to change these parameters, according to set rules and configurations.

Each Steward is designed to have a specific set of segregated responsibilities in an effort to avoid having to redeploy the entire original Steward. Instead, only the specific steward whose responsibilities are affected will have to be redeployed.

### [GhoAaveSteward](src/contracts/misc/GhoAaveSteward.sol)

This Steward manages parameters related to the GHO token. Specifically, it allows the Risk Council to change the following parameters:

- Borrow Rate
- Borrow Cap
- Supply Cap

In addition, the Aave DAO is allowed to change the configuration for the GHO Borrow Rate. This puts restrictions on how much the Risk Council is allowed to change parameters related to the borrow rate. There are 4 parameters that comprise the borrow rate:

- optimalUsageRatio
- baseVariableBorrowRate
- variableRateSlope1
- variableRateSlope2
  For example, the Aave DAO can specify that the optimalUsageRatio variable may only be changed by 3% at a time.

### [GhoBucketSteward](src/contracts/misc/GhoBucketSteward.sol)

This Steward allows the Risk Council to set the bucket capacities of controlled facilitators. Additionally, it allows the Aave DAO to add or remove controlled facilitators.

### [GhoCcipSteward](src/contracts/misc/GhoCcipSteward.sol)

This Steward allows the management of parameters related to CCIP. It allows the Risk Council to update the CCIP bridge limit, and to update the CCIP rate limit configuration.

### [GhoGsmSteward](src/contracts/misc/GhoGsmSteward.sol)

This Steward allows the Risk Council to update the exposure cap of the GSM, and to update the buy and sell fees of the GSM.

### [RiskCouncilControlled](src/contracts/misc/RiskCouncilControlled.sol)

This is a helper contract to define the approved Risk Council and enforce its authority to call permissioned functions.
