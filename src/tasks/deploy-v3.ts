import { task } from 'hardhat/config';
import { getNetwork } from '../helpers/misc-utils';

task('deploy-v3', 'deploy v3').setAction(async (_, hre) => {
  console.log('Network:', await getNetwork());
  console.log('BlockNumber:', (await hre.ethers.provider.getBlockNumber()).toString());
  console.log('Network:', await hre.ethers.provider.getNetwork());
  await hre.run('deploy', { tags: 'market,full_gho_deploy' });
  await hre.run('gho-setup', {deploying: true});
});
