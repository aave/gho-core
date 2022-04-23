import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';

task('deploy-antei-oracle', 'deploy antei token').setAction(async (_, hre) => {
  await hre.run('set-DRE');

  const anteiOracle_factory = await DRE.ethers.getContractFactory('AnteiOracle');
  const anteiOracle = await anteiOracle_factory.deploy();

  console.log(`ASD Oracle:                   ${anteiOracle.address}`);
  return anteiOracle.address;
});
