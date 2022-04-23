import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';

task('deploy-antei-erc20', 'deploy antei token').setAction(async (_, hre) => {
  await hre.run('set-DRE');

  const asd_Factory = await DRE.ethers.getContractFactory('AnteiStableDollarEntities');
  const asd = await asd_Factory.deploy([]);

  console.log(`ASD Address:                   ${asd.address}`);
  return asd.address;
});
