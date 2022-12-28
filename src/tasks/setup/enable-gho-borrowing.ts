import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { getPoolConfiguratorProxy } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { getGhoToken } from '../../helpers/contract-getters';

task('enable-gho-borrowing', 'Enable variable borrowing on GHO')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;

    let gho;
    let poolConfigurator;

    if (params.deploying) {
      gho = await ethers.getContract('GhoToken');
      poolConfigurator = await getPoolConfiguratorProxy();
    } else {
      const contracts = require('../../../contracts.json');

      gho = await getGhoToken(contracts.GhoToken);
      poolConfigurator = await getPoolConfiguratorProxy(contracts['PoolConfigurator-Proxy-Test']);
    }

    const [_deployer] = await hre.ethers.getSigners();
    poolConfigurator = poolConfigurator.connect(_deployer);

    let error = false;
    const enableBorrowingTx = await poolConfigurator.setReserveBorrowing(gho.address, true);

    const enableBorrowingTxReceipt = await enableBorrowingTx.wait();
    if (enableBorrowingTxReceipt.events) {
      const borrowingEnabledEvents = enableBorrowingTxReceipt.events.filter(
        (e) => e.event === 'ReserveBorrowing'
      );
      if (borrowingEnabledEvents[0].args) {
        console.log(
          `Borrowing set to ${borrowingEnabledEvents[0].args.enabled} on asset: \n\t${borrowingEnabledEvents[0].args.asset}}`
        );
      } else {
        error = true;
      }
    } else {
      error = true;
    }
    if (error) {
      console.log(`ERROR: borrowing no enabled correctly`);
    }
  });
