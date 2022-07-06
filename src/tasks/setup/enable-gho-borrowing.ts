import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { getLendingPoolConfigurator } from '../../helpers/contract-getters';

task('enable-gho-borrowing', 'Enable variable borrowing on GHO').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  const gho = await ethers.getContract('GhoToken');

  let lendingPoolConfiguratior = await getLendingPoolConfigurator(
    aaveMarketAddresses.lendingPoolConfigurator
  );
  const governanceSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
  lendingPoolConfiguratior = lendingPoolConfiguratior.connect(governanceSigner);

  let error = false;
  const enableBorrowingTx = await lendingPoolConfiguratior.enableBorrowingOnReserve(
    gho.address,
    false
  );
  const enableBorrowingTxReceipt = await enableBorrowingTx.wait();
  if (enableBorrowingTxReceipt.events) {
    const borrowingEnabledEvents = enableBorrowingTxReceipt.events.filter(
      (e) => e.event === 'BorrowingEnabledOnReserve'
    );
    if (borrowingEnabledEvents[0].args) {
      console.log(
        `Borrowing enabled on asset:\n\t${borrowingEnabledEvents[0].args.asset}\n\tstable borrowing: ${borrowingEnabledEvents[0].args.stableRateEnabled}`
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
