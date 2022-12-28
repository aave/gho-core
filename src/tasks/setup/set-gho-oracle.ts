import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { getAaveOracle } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { getGhoOracle, getGhoToken } from '../../helpers/contract-getters';

task('set-gho-oracle', 'Set oracle for gho in Aave Oracle')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;

    let gho;
    let ghoOracle;
    let aaveOracle;

    // get contracts
    if (params.deploying) {
      gho = await ethers.getContract('GhoToken');
      ghoOracle = await ethers.getContract('GhoOracle');
      aaveOracle = await getAaveOracle();
    } else {
      const contracts = require('../../../contracts.json');

      gho = await getGhoToken(contracts.GhoToken);
      ghoOracle = await getGhoOracle(contracts.GhoOracle);
      aaveOracle = await getAaveOracle(contracts['AaveOracle-Test']);
    }

    const [_deployer] = await hre.ethers.getSigners();
    aaveOracle = aaveOracle.connect(_deployer);

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
