import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { ghoEntityConfig } from '../../helpers/config';
import { getAaveProtocolDataProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { getGhoToken } from '../../helpers/contract-getters';
import { IGhoToken } from '../../../types';

task('add-gho-as-entity', 'Adds Aave as a gho entity')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;

    let gho;
    let aaveDataProvider;
    let ghoATokenAddress;

    // get contracts
    if (params.deploying) {
      gho = await ethers.getContract('GhoToken');
      aaveDataProvider = await getAaveProtocolDataProvider();
    } else {
      const contracts = require('../../../contracts.json');

      gho = await getGhoToken(contracts.GhoToken);
      aaveDataProvider = await getAaveProtocolDataProvider(contracts['PoolDataProvider-Test']);
    }
    const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
    ghoATokenAddress = tokenProxyAddresses.aTokenAddress;

    const [deployer] = await hre.ethers.getSigners();

    const aaveEntity: IGhoToken.FacilitatorStruct = {
      label: ghoEntityConfig.label,
      bucketCapacity: ghoEntityConfig.mintLimit,
      bucketLevel: 0,
    };

    const addEntityTx = await gho
      .connect(deployer)
      .addFacilitator(tokenProxyAddresses.aTokenAddress, aaveEntity);
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
  });
