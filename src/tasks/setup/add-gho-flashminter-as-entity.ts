import { task } from 'hardhat/config';
import { DRE, getNetwork, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { ghoEntityConfig } from '../../helpers/config';
import { IGhoToken } from '../../../types';

task('add-gho-flashminter-as-entity', 'Adds FlashMinter as a gho entity').setAction(
  async (_, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;
    const [deployer] = await hre.ethers.getSigners();

    let gho = await ethers.getContract('GhoToken');
    gho = gho.connect(deployer);
    let ghoFlashMinter = await ethers.getContract('GhoFlashMinter');
    ghoFlashMinter = ghoFlashMinter.connect(deployer);

    const network = getNetwork();
    if (network == 'mainnet') {
      const governanceSigner = await impersonateAccountHardhat(
        aaveMarketAddresses[network].shortExecutor
      );
      gho = await gho.connect(governanceSigner);
    }

    const aaveEntity: IGhoToken.FacilitatorStruct = {
      label: ghoEntityConfig.label,
      bucketCapacity: ghoEntityConfig.flashMinterCapacity,
      bucketLevel: 0,
    };

    const addEntityTx = await gho.addFacilitator(ghoFlashMinter.address, aaveEntity);
    const addEntityTxReceipt = await addEntityTx.wait();

    let error = false;
    if (addEntityTxReceipt && addEntityTxReceipt.events) {
      const newEntityEvents = addEntityTxReceipt.events.filter(
        (e) => e.event === 'FacilitatorAdded'
      );
      if (newEntityEvents.length > 0) {
        console.log(
          `Address added as a facilitator: ${JSON.stringify(newEntityEvents[0].args[0])}`
        );
      } else {
        error = true;
      }
    } else {
      error = true;
    }
    if (error) {
      console.log(`ERROR: Aave not added as GHO entity`);
    }
  }
);
