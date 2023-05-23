import { task } from 'hardhat/config';
import { getACLManager } from '@aave/deploy-v3';
import { GhoSteward } from '../../../types/src/contracts/facilitators/aave/misc/GhoSteward';
import { getGhoToken } from '../../helpers/contract-getters';
import { ethers } from 'ethers';

const BUCKET_MANAGER_ROLE = ethers.utils.id('BUCKET_MANAGER_ROLE');

task('add-gho-steward', 'Adds ghoSteward poolAdmin role').setAction(async (_, hre) => {
  const { ethers } = hre;

  const ghoSteward = (await ethers.getContract('GhoSteward')) as GhoSteward;
  const aclArtifact = await getACLManager();
  const addPoolAdminTx = await aclArtifact.addPoolAdmin(ghoSteward.address);

  const addPoolAdminTxReceipt = await addPoolAdminTx.wait();
  const newPoolAdminEvents = addPoolAdminTxReceipt.events?.find((e) => {
    return e.event === 'RoleGranted';
  });
  if (newPoolAdminEvents?.args) {
    console.log(`Gho steward added as a poolAdmin: ${JSON.stringify(newPoolAdminEvents.args[0])}`);
  } else {
    throw new Error(`Error at adding entity. Check tx: ${addPoolAdminTx.hash}`);
  }

  const ghoToken = await getGhoToken();
  await (await ghoToken.grantRole(BUCKET_MANAGER_ROLE, ghoSteward.address)).wait();
  const added = await ghoToken.hasRole(BUCKET_MANAGER_ROLE, ghoSteward.address);
  if (added) {
    console.log('Gho steward added as bucketManager');
  } else {
    throw new Error(`Error at adding entity ad BUCKET_MANAGER`);
  }

  return;
});
