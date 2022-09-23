import { task } from 'hardhat/config';
import rawBRE from 'hardhat';

task('deploy-v3', 'deploy v3').setAction(async (_, hre) => {
  // await rawBRE.run('set-DRE');
  await hre.deployments.fixture(['market']);
  await hre.deployments.fixture(['full_gho_deploy']);
});
