import { task } from 'hardhat/config';

import { getAaveOracle } from '@aave/deploy-v3';

task('set-gho-oracle', 'Set oracle for gho in Aave Oracle').setAction(async (_, hre) => {
  const { ethers } = hre;

  const gho = await ethers.getContract('GhoToken');
  const ghoOracle = await ethers.getContract('GhoOracle');
  const aaveOracle = await getAaveOracle();

  const setSourcesTx = await aaveOracle.setAssetSources([gho.address], [ghoOracle.address]);
  const setSourcesTxReceipt = await setSourcesTx.wait();

  const assetSourceUpdate = setSourcesTxReceipt.events?.find(
    (e) => e.event === 'AssetSourceUpdated'
  );

  if (assetSourceUpdate?.args) {
    const { source, asset } = assetSourceUpdate.args;
    console.log(`Source set to: ${source} for asset ${asset}`);
  } else {
    throw new Error(`Error at oracle setup, check tx: ${setSourcesTxReceipt.transactionHash}`);
  }
});
