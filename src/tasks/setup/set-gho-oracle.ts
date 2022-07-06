import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { getAaveOracle } from '../../helpers/contract-getters';

task('set-gho-oracle', 'Set oracle for gho in Aave Oracle').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  const gho = await ethers.getContract('GhoToken');
  const ghoOracle = await ethers.getContract('GhoOracle');
  const governanceSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
  const aaveOracle = (await getAaveOracle(aaveMarketAddresses.aaveOracle)).connect(
    governanceSigner
  );

  let error = false;
  const setSourcesTx = await aaveOracle.setAssetSources([gho.address], [ghoOracle.address]);
  const setSourcesTxReceipt = await setSourcesTx.wait();
  if (setSourcesTxReceipt && setSourcesTxReceipt.events) {
    const assetSourceUpdates = setSourcesTxReceipt.events.filter(
      (e) => e.event === 'AssetSourceUpdated'
    );
    if (assetSourceUpdates.length > 0 && assetSourceUpdates[0].args) {
      console.log(
        `Source set to: ${assetSourceUpdates[0].args.source} for asset ${assetSourceUpdates[0].args.asset}`
      );
    } else {
      error = true;
    }
  } else {
    error = true;
  }
  if (error) {
    console.log(`ERROR: oracle not configured correctly`);
  }
});
