import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { getPoolConfiguratorProxy } from '@aave/deploy-v3/dist/helpers/contract-getters';

task('enable-gho-borrowing', 'Enable variable borrowing on GHO').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  const gho = await ethers.getContract('GhoToken');
  let poolConfigurator = await getPoolConfiguratorProxy();

  const { deployer } = await hre.getNamedAccounts();
  const governanceSigner = await impersonateAccountHardhat(deployer);
  poolConfigurator = poolConfigurator.connect(governanceSigner);

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
