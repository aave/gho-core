import { task } from 'hardhat/config';
import rawBRE from 'hardhat';

task('deploy-v3', 'deploy v3').setAction(async (_, hre) => {
  await hre.deployments.fixture(['market']);
});
