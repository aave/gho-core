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

  const stkAaveProxyAsStkAave = await getStakedAave(helperAddresses.stkAave);

  const previousRevision = await stkAaveProxyAsStkAave.REVISION();
  const previousImplementationAsBytes = await ethers.provider.send('eth_getStorageAt', [
    helperAddresses.stkAave,
    '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc',
    'latest',
  ]);
  const previousimplementationAddress = ethers.utils.getAddress(
    ethers.utils.hexDataSlice(previousImplementationAsBytes, 12)
  );

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

  let error = false;
  console.log(`trying to upgrade stkAave...`);
  const upgradeTx = await stkAaveProxy.upgradeToAndCall(
    newStakedAaveImpl.address,
    stakedAaveEncodedInitialize
  );

  await expect(await upgradeTx)
    .to.emit(stkAaveProxy, 'Upgraded')
    .withArgs(newStakedAaveImpl.address);

  console.log(`StkAave implementation set to: ${newStakedAaveImpl.address}`);
  console.log(`Previous Implementation: ${previousimplementationAddress}`);
  console.log(`Previous Revision ${previousRevision}`);
  console.log(`New Revision ${await stkAaveProxyAsStkAave.REVISION()}`);
});
