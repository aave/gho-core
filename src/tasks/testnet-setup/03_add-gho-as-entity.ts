import { task } from 'hardhat/config';

import { ghoEntityConfig } from '../../helpers/config';
import { getAaveProtocolDataProvider } from '@aave/deploy-v3';
import { GhoToken, IGhoToken } from '../../../types';

task('add-gho-as-entity', 'Adds Aave as a gho entity').setAction(async (_, hre) => {
  const { ethers } = hre;

  const gho = (await ethers.getContract('GhoToken')) as GhoToken;
  const aaveDataProvider = await getAaveProtocolDataProvider();

  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);

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

  const newEntityEvents = addEntityTxReceipt.events?.find((e) => e.event === 'FacilitatorAdded');

  if (newEntityEvents?.args) {
    console.log(`Address added as a facilitator: ${JSON.stringify(newEntityEvents.args[0])}`);
  } else {
    throw new Error(
      `Error when adding facilitator. Check tx ${addEntityTxReceipt.transactionHash}`
    );
  }
});
