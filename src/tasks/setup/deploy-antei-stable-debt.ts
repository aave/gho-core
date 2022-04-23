import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/aave-v2-addresses';

task('deploy-antei-stable-debt', 'Deploy Antei Stable Debt Token')
  .addParam('underlyingAssetAddress')
  .addParam('tokenName')
  .addParam('tokenSymbol')
  .setAction(async ({ underlyingAssetAddress, tokenName, tokenSymbol }, hre) => {
    await hre.run('set-DRE');

    const { pool, incentivesController } = aaveMarketAddresses;

    const stableDebtImplementation_Factory = await DRE.ethers.getContractFactory('StableDebtToken');
    const stableDebtImplementation = await stableDebtImplementation_Factory.deploy(
      pool,
      underlyingAssetAddress,
      tokenName,
      tokenSymbol,
      incentivesController
    );

    console.log(`Stable Debt Implementation:    ${stableDebtImplementation.address}`);
    return stableDebtImplementation.address;
  });
