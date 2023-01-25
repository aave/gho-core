import { formatEther } from 'ethers/lib/utils';
import { task } from 'hardhat/config';

task(`network-check`, `Check network block and deployment account`).setAction(async (_, hre) => {
  const [_deployer] = await hre.ethers.getSigners();
  const deployerAddress = await _deployer.getAddress();
  const deployerBalance = await hre.ethers.provider.getBalance(deployerAddress);

  console.log(`Network: ${hre.network.name}`);
  console.log(`Block Number: ${await hre.ethers.provider.getBlockNumber()}`);
  console.log(`Deployer: ${deployerAddress}`);
  console.log(`Balance: ${formatEther(deployerBalance)}`);
});
