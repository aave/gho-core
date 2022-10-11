import { task } from 'hardhat/config';
import { DRE, setDRE } from '../helpers/misc-utils';

task(`network-check`, `Check network block and deployment account`).setAction(async (_, _DRE) => {
  console.log(`Current Block Number: ${await _DRE.ethers.provider.getBlockNumber()}`);

  const [_deployer] = await _DRE.ethers.getSigners();
  const deployerAddress = await _deployer.getAddress();
  console.log(`Deploy address: ${deployerAddress}`);

  const deployerBalance = await _DRE.ethers.provider.getBalance(deployerAddress);
  console.log(`Deploy balance: ${deployerBalance}`);
});
