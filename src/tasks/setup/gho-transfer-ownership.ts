import { task } from 'hardhat/config';
import { getNetwork } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';

task('gho-transfer-ownership', 'Transfer Ownership of Gho')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    const network = getNetwork();
    const { shortExecutor } = aaveMarketAddresses[network];

    const gho = await hre.ethers.getContract('GhoToken');
    const transferOwnershipTx = await gho.transferOwnership(shortExecutor);
    await transferOwnershipTx.wait();

    console.log(`GHO ownership transferred to:  ${shortExecutor}`);
  });
