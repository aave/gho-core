import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/aave-v2-addresses';

task('deploy-antei-variable-debt', 'Deploy Antei Variable Debt Token')
  .addParam('underlyingAssetAddress')
  .addParam('tokenName')
  .addParam('tokenSymbol')
  .setAction(async ({ underlyingAssetAddress, tokenName, tokenSymbol }, hre) => {
    await hre.run('set-DRE');

    const { pool, incentivesController } = aaveMarketAddresses;

    const variableDebtImplementation_Factory = await DRE.ethers.getContractFactory(
      'VariableDebtToken'
    );
    const variableDebtImplementation = await variableDebtImplementation_Factory.deploy(
      pool,
      underlyingAssetAddress,
      tokenName,
      tokenSymbol,
      incentivesController
    );

    console.log(`Variable Debt Implementation:  ${variableDebtImplementation.address}`);
    return variableDebtImplementation.address;
  });
