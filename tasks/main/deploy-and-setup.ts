import { task } from 'hardhat/config';

task('deploy-and-setup', 'Deploy fresh 3.0.1 market instance and setup GHO').setAction(
  async (_, hre) => {
    console.log('BlockNumber:', (await hre.ethers.provider.getBlockNumber()).toString());
    console.log('Network:', await hre.ethers.provider.getNetwork());

    await hre.run('deploy', {
      tags: 'market,periphery-post,after-deploy,full_gho_deploy',
      noCompile: true,
    });
    await hre.run('gho-testnet-setup');
  }
);
