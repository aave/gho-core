import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import {
  getBaseImmutableAdminUpgradeabilityProxy,
  getLendingPool,
} from '../../helpers/contract-getters';

task('upgrade-pool', 'Upgrade pool for antei').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  const poolProxyAsPool = await getLendingPool(aaveMarketAddresses.pool);
  const previousRevision = await poolProxyAsPool.LENDINGPOOL_REVISION();

  const nextPool = await ethers.getContract('LendingPool');
  const addressesProviderSigner = await impersonateAccountHardhat(
    aaveMarketAddresses.addressesProvider
  );

  const poolProxy = (
    await getBaseImmutableAdminUpgradeabilityProxy(aaveMarketAddresses.pool)
  ).connect(addressesProviderSigner);

  let error = false;
  console.log(`trying to upgrade pool...`);
  const upgradeTx = await poolProxy.upgradeTo(nextPool.address);
  const upgradeTxReceipt = await upgradeTx.wait();
  if (upgradeTxReceipt && upgradeTxReceipt.events) {
    const upgradeEvents = upgradeTxReceipt.events.filter((e) => e.event === 'Upgraded');
    if (upgradeEvents.length > 0 && upgradeEvents[0].args) {
      console.log(`Pool implementation set to: ${upgradeEvents[0].args.implementation}`);
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
