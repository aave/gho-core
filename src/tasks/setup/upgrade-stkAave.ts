import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses, helperAddresses } from '../../helpers/config';
import {
  getBaseImmutableAdminUpgradeabilityProxy,
  getAaveProtocolDataProvider,
  getStakedAave,
} from '../../helpers/contract-getters';
import { expect } from 'chai';

task('upgrade-stkAave', 'Upgrade Staked Aave').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  const newStakedAaveImpl = await ethers.getContract('StakedTokenV2Rev4');

  const governanceSigner = await impersonateAccountHardhat(helperAddresses.longExecutor);
  const stkAaveProxy = (
    await getBaseImmutableAdminUpgradeabilityProxy(helperAddresses.stkAave)
  ).connect(governanceSigner);

  let asd = await ethers.getContract('AnteiStableDollarEntities');
  const aaveDataProvider = await getAaveProtocolDataProvider(
    aaveMarketAddresses.aaveProtocolDataProvider
  );
  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(asd.address);
  let anteiVariableDebtTokenAddress = tokenProxyAddresses.variableDebtTokenAddress;

  const stakedAaveEncodedInitialize = newStakedAaveImpl.interface.encodeFunctionData('initialize', [
    anteiVariableDebtTokenAddress,
  ]);

  console.log(`trying to upgrade stkAave...`);
  const upgradeTx = await stkAaveProxy.upgradeToAndCall(
    newStakedAaveImpl.address,
    stakedAaveEncodedInitialize
  );

  await expect(await upgradeTx)
    .to.emit(stkAaveProxy, 'Upgraded')
    .withArgs(newStakedAaveImpl.address);

  console.log(`StkAave implementation set to: ${newStakedAaveImpl.address}`);
});
