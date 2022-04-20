import { task } from 'hardhat/config';
import { DRE } from '../helpers/misc-utils';
// import { Signer } from 'ethers';
// import { DRE } from '../../helpers/misc-utils';
// import { runTaskWithRetry } from '../../helpers/etherscan-verification';

task('deploy-antei-token', 'deploy antei token').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  console.log(`Hello!!`);

  const addresses = await DRE.ethers.getSigners();
  const deployer = addresses[0];

  console.log(`Signer: ${await deployer.getAddress()}`);
  console.log(`Balance: ${(await deployer.getBalance()).toString()}`);

  // const constructorArguments: [string, string, string, string, string, string] = [
  //   executor,
  //   delay,
  //   gracePeriod,
  //   minimumDelay,
  //   maximumDelay,
  //   guardian,
  // ];

  // if (verify) {
  //   const params = {
  //     address: arcTimelock.address,
  //     constructorArguments,
  //   };
  //   await runTaskWithRetry('verify:verify', params, 3, 2000, () => {});
  // }

  // console.log('=== INFO ===');
  // console.log('Deployed Timelock contract at:', arcTimelock.address, `\n`);

  // return arcTimelock.address;
});
