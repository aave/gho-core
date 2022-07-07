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

  let gho = await ethers.getContract('GhoToken');
  const aaveDataProvider = await getAaveProtocolDataProvider(
    aaveMarketAddresses.aaveProtocolDataProvider
  );
  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
  let ghoVariableDebtTokenAddress = tokenProxyAddresses.variableDebtTokenAddress;

  const stakedAaveEncodedInitialize = newStakedAaveImpl.interface.encodeFunctionData('initialize', [
    ghoVariableDebtTokenAddress,
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
