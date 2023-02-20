import { GhoManager } from '../../../types/src/contracts/facilitators/aave/misc/GhoManager';
import { task } from 'hardhat/config';
import { ghoEntityConfig } from '../../helpers/config';
import { getACLManager } from '@aave/deploy-v3';

task('add-gho-manager', 'Adds ghomanager pooladmin role').setAction(async (_, hre) => {
  const { ethers } = hre;

  const ghoManager = (await ethers.getContract('GhoManager')) as GhoManager;
  const aclArtifact = await getACLManager();
  const addPoolAdminTx = await aclArtifact.addPoolAdmin(ghoManager.address);

  const addPoolAdminTxReceipt = await addPoolAdminTx.wait();
  const newPoolAdminEvents = addPoolAdminTxReceipt.events?.find((e) => {
    return e.event === 'RoleGranted';
  });
  if (newPoolAdminEvents?.args) {
    console.log(`Gho manager added as a pooladmin: ${JSON.stringify(newPoolAdminEvents.args[0])}`);
  } else {
    throw new Error(`Error at adding entity. Check tx: ${addPoolAdminTx.hash}`);
  }
  return;
});
