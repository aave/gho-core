# GSM L2

## Motivation

The main idea of having a GSM for L2s, is to earn fees for the DAO and also be able to accomodate swaps for GHO at a DAO controlled exchange rate. Currently, it's impossible to support a GSM on a Layer 2 chain because GHO can only be minted (and burned) on Ethereum Mainnet as part of its design. Because of this, a GSM L2 will need GHO provided to it in order to function.

## Design

GHO on Ethereum Mainnet is provided via "facilitators" and the idea for a GSM L2 is to have a facilitator that mints and immediately bridges the GHO to a Layer 2 blockchain, such as Arbitrum or Base. The contract that receives the GHO on the L2 can then provide liquidty to the deployed GSM on the L2.

For example, 10M of GHO is minted on Mainnet, bridged over to Base, and then the contract that receives the GHO, can provide up to 10M of liquidity to the contract.

On Mainnet, because the GSM mints/burns GHO, the liquidity can be accessed at all times, even if fees are incurred in the GSM (and the original supply of GHO continues to decrease). In the GSML2, this is not possible and if fees are turned on, GHO is going to be coming into the contract again when a user purchases the exogenous asset, but a portion of it will go into fees. This means the available GHO liquidity is going to decrease at small clips. In order to mitigate this, extra GHO should be provided into the GSM originally in order to avoid this issue and at a later stage, the GHO can be replenished. Alternatively, fees can be turned off for the GSM on L2 though that would eliminate a source of revenue for the DAO through a transaction.

## Burning the GHO

The GSML2 contract can be seized at any point in time, and once seized, the GHO can be sent back to the original contract that provided the liquidity. From there, the GHO can be bridged back to Mainnet to be burned.
