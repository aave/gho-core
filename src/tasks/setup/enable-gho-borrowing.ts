import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { getPoolConfiguratorProxy } from '@aave/deploy-v3/dist/helpers/contract-getters';

task('enable-gho-borrowing', 'Enable variable borrowing on GHO').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  const gho = await ethers.getContract('GhoToken');
  let poolConfigurator = await getPoolConfiguratorProxy();

  // const { deployer } = await hre.getNamedAccounts();
  // const governanceSigner = await impersonateAccountHardhat(deployer);

  const [_deployer] = await hre.ethers.getSigners();
  poolConfigurator = poolConfigurator.connect(_deployer);

  const deployerAddress = await _deployer.getAddress();
  console.log(`Deploy address: ${deployerAddress}`);

  const deployerBalance = await hre.ethers.provider.getBalance(deployerAddress);
  console.log(`Deploy balance: ${deployerBalance}`);

  let error = false;
  console.log(`submitting transaction...`);
  const enableBorrowingTx = await poolConfigurator.setReserveBorrowing(gho.address, true);

  console.log(`transaction submitted`);
  console.log(JSON.stringify(enableBorrowingTx, null, 2));

  const enableBorrowingTxReceipt = await enableBorrowingTx.wait();
  console.log(`wait complete`);
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
