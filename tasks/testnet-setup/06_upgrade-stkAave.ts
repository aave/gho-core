import { task } from 'hardhat/config';
import {
  getAaveProtocolDataProvider,
  getProxyAdminBySlot,
  STAKE_AAVE_PROXY,
} from '@aave/deploy-v3';
import { getBaseImmutableAdminUpgradeabilityProxy } from '../../helpers/contract-getters';
import { impersonateAccountHardhat } from '../../helpers/misc-utils';
import { StakedAaveV3__factory } from '../../types';

task('upgrade-stkAave', 'Upgrade Staked Aave').setAction(async (_, hre) => {
  const { ethers } = hre;
  const signers = await hre.ethers.getSigners();
  const shortExecutor = '0xee56e2b3d491590b5b31738cc34d5232f378a8d5';

  const gho = await ethers.getContract('GhoToken');
  const aaveDataProvider = await getAaveProtocolDataProvider();
  const newStakedAaveImpl = await ethers.getContract('StakedAaveV3Impl');
  const stkAave = (await hre.deployments.get(STAKE_AAVE_PROXY)).address;

  const admin = await getProxyAdminBySlot(stkAave);

  const signerAdmin = signers.find(({ address }) => address == admin);
  const [deploySigner] = signers;

  if (!signerAdmin) {
    throw `Error: Signers does not contain the stkAave Admin Address.\nDeployer ${signers[0].address}\nAdmin: ${admin}`;
  }

  const stkAaveProxy = (await getBaseImmutableAdminUpgradeabilityProxy(stkAave)).connect(
    signerAdmin
  );

  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
  const ghoVariableDebtTokenAddress = tokenProxyAddresses.variableDebtTokenAddress;
  let instance = StakedAaveV3__factory.connect(stkAaveProxy.address, deploySigner);

  const stakedAaveEncodedInitialize = newStakedAaveImpl.interface.encodeFunctionData('initialize', [
    signerAdmin.address,
    signerAdmin.address,
    signerAdmin.address,
    '0',
    await instance.COOLDOWN_SECONDS(),
  ]);

  const upgradeTx = await stkAaveProxy.upgradeToAndCall(
    newStakedAaveImpl.address,
    stakedAaveEncodedInitialize
  );
  await upgradeTx.wait();

  instance = await StakedAaveV3__factory.connect(
    stkAaveProxy.address,
    await impersonateAccountHardhat(shortExecutor)
  );
  await instance.setGHODebtToken(ghoVariableDebtTokenAddress);

  console.log(`stkAave upgradeTx.hash: ${upgradeTx.hash}`);
  console.log(`StkAave implementation set to: ${newStakedAaveImpl.address}`);
});
