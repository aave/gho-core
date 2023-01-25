import { GhoFlashMinter } from '../../../types/src/contracts/facilitators/flashMinter/GhoFlashMinter';
import { GhoToken } from '../../../types/src/contracts/gho/GhoToken';
import { task } from 'hardhat/config';
import { ghoEntityConfig } from '../../helpers/config';
import { IGhoToken } from '../../../types';

task('add-gho-flashminter-as-entity', 'Adds FlashMinter as a gho entity').setAction(
  async (_, hre) => {
    const { ethers } = hre;

    const gho = (await ethers.getContract('GhoToken')) as GhoToken;
    const ghoFlashMinter = (await ethers.getContract('GhoFlashMinter')) as GhoFlashMinter;

    const aaveEntity: IGhoToken.FacilitatorStruct = {
      label: ghoEntityConfig.label,
      bucketCapacity: ghoEntityConfig.flashMinterCapacity,
      bucketLevel: 0,
    };

    const addEntityTx = await gho.addFacilitator(ghoFlashMinter.address, aaveEntity);
    const addEntityTxReceipt = await addEntityTx.wait();

    const newEntityEvents = addEntityTxReceipt.events?.find((e) => e.event === 'FacilitatorAdded');
    if (newEntityEvents?.args) {
      console.log(`Address added as a facilitator: ${JSON.stringify(newEntityEvents.args[0])}`);
    } else {
      throw new Error(`Error at adding entity. Check tx: ${addEntityTx.hash}`);
    }
  }
);
