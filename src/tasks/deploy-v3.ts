import { task } from 'hardhat/config';

task('deploy-v3', 'deploy v3').setAction(async (_, hre) => {
  // await rawBRE.run('set-DRE');
  await hre.deployments.fixture(['market', 'full_gho_deploy']);
  await hre.run('gho-setup');
});
