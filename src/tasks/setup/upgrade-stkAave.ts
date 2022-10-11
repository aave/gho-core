import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { getBaseImmutableAdminUpgradeabilityProxy } from '../../helpers/contract-getters';
import { getAaveProtocolDataProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { expect } from 'chai';
import { getNetwork } from '../../helpers/misc-utils';

task('upgrade-stkAave', 'Upgrade Staked Aave').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  const network = getNetwork();
  const { longExecutor, stkAave } = aaveMarketAddresses[network];

  const newStakedAaveImpl = await ethers.getContract('StakedTokenV2Rev4');

  const [_deployer] = await hre.ethers.getSigners();

  const stkAaveProxy = (await getBaseImmutableAdminUpgradeabilityProxy(stkAave)).connect(_deployer);

  let gho = await ethers.getContract('GhoToken');
  const aaveDataProvider = await getAaveProtocolDataProvider();
  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
  let ghoVariableDebtTokenAddress = tokenProxyAddresses.variableDebtTokenAddress;

  const stakedAaveEncodedInitialize = newStakedAaveImpl.interface.encodeFunctionData('initialize', [
    ghoVariableDebtTokenAddress,
  ]);

  const upgradeTx = await stkAaveProxy.upgradeToAndCall(
    newStakedAaveImpl.address,
    stakedAaveEncodedInitialize
  );

  console.log(`stkAave upgradeTx.hash: ${upgradeTx.hash}`);
  console.log(`StkAave implementation set to: ${newStakedAaveImpl.address}`);
});
