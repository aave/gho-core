import { GhoToken } from './../../../types/src/contracts/gho/GhoToken';
import { task } from 'hardhat/config';

task('gho-transfer-ownership', 'Transfer Ownership of Gho')
  .addParam('newOwner')
  .setAction(async ({ newOwner }, hre) => {
    const DEFAULT_ADMIN_ROLE = hre.ethers.utils.hexZeroPad('0x00', 32);
    const gho = (await hre.ethers.getContract('GhoToken')) as GhoToken;
    const grantAdminRoleTx = await gho.grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    await grantAdminRoleTx.wait();
    const signers = await hre.ethers.getSigners();
    const removeAdminRoleTx = await gho.renounceRole(DEFAULT_ADMIN_ROLE, users[0].address);

    console.log(`GHO ownership transferred to:  ${newOwner}`);
  });
