import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { getAaveOracle } from '@aave/deploy-v3/dist/helpers/contract-getters';

task('set-gho-oracle', 'Set oracle for gho in Aave Oracle').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  const gho = await ethers.getContract('GhoToken');
  const ghoOracle = await ethers.getContract('GhoOracle');

  const { deployer } = await hre.getNamedAccounts();
  const governanceSigner = await impersonateAccountHardhat(deployer);

  const aaveOracle = (await getAaveOracle()).connect(governanceSigner);

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
