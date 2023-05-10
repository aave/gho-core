import { GhoToken } from './../../../types/src/contracts/gho/GhoToken';
import { task } from 'hardhat/config';

task('gho-transfer-ownership', 'Transfer Ownership of Gho')
  .addParam('newOwner')
  .setAction(async ({ newOwner }, hre) => {
    const gho = (await hre.ethers.getContract('GhoToken')) as GhoToken;
    const transferOwnershipTx = await gho.transferOwnership(newOwner);
    await transferOwnershipTx.wait();

    console.log(`GHO ownership transferred to:  ${newOwner}`);
  });
