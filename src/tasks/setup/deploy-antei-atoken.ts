import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/aave-v2-addresses';

task('deploy-antei-atoken', 'Deploy Antei AToken')
  .addParam('underlyingAssetAddress')
  .addParam('tokenName')
  .addParam('tokenSymbol')
  .setAction(async ({ underlyingAssetAddress, tokenName, tokenSymbol }, hre) => {
    await hre.run('set-DRE');

    const { pool, treasury, incentivesController } = aaveMarketAddresses;

    const aTokenImplementation_Factory = await DRE.ethers.getContractFactory('AToken');
    const aTokenImplementation = await aTokenImplementation_Factory.deploy(
      pool,
      underlyingAssetAddress,
      treasury,
      tokenName,
      tokenSymbol,
      incentivesController
    );

    console.log(`AToken Implementation:         ${aTokenImplementation.address}`);
    return aTokenImplementation.address;
  });
