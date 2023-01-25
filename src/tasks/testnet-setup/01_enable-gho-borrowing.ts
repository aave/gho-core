import { task } from 'hardhat/config';

import { getPoolConfiguratorProxy } from '@aave/deploy-v3';

task('enable-gho-borrowing', 'Enable variable borrowing on GHO').setAction(async (_, hre) => {
  const { ethers } = hre;

  const gho = await ethers.getContract('GhoToken');
  const poolConfigurator = await getPoolConfiguratorProxy();

  const enableBorrowingTx = await poolConfigurator.setReserveBorrowing(gho.address, true);

  const enableBorrowingTxReceipt = await enableBorrowingTx.wait();

  const borrowingEnabledEvent = enableBorrowingTxReceipt.events?.find(
    (e) => e.event === 'ReserveBorrowing'
  );
  if (borrowingEnabledEvent?.args) {
    const { enabled, asset } = borrowingEnabledEvent.args;
    console.log(`Borrowing set to ${enabled} on asset: \n\t${asset}}`);
  } else {
    throw new Error(
      `Error at gho borrowing initialization. Check tx: ${enableBorrowingTxReceipt.transactionHash}`
    );
  }
});
