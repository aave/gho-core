import { task } from 'hardhat/config';
import {
  getAaveProtocolDataProvider,
  getProxyAdminBySlot,
  STAKE_AAVE_PROXY,
} from '@aave/deploy-v3';
import { getBaseImmutableAdminUpgradeabilityProxy } from '../../helpers/contract-getters';

task('upgrade-stkAave', 'Upgrade Staked Aave').setAction(async (_, hre) => {
  const { ethers } = hre;
  const signers = await hre.ethers.getSigners();

  const gho = await ethers.getContract('GhoToken');
  const aaveDataProvider = await getAaveProtocolDataProvider();
  const newStakedAaveImpl = await ethers.getContract('StakedTokenV2Rev4Impl');
  const stkAave = (await hre.deployments.get(STAKE_AAVE_PROXY)).address;

  const admin = await getProxyAdminBySlot(stkAave);

  const signerAdmin = signers.find(({ address }) => address == admin);

  if (!signerAdmin) {
    throw `Error: Signers does not contain the stkAave Admin Address.\nDeployer ${signers[0].address}\nAdmin: ${admin}`;
  }

  const stkAaveProxy = (await getBaseImmutableAdminUpgradeabilityProxy(stkAave)).connect(
    signerAdmin
  );

  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
  const ghoVariableDebtTokenAddress = tokenProxyAddresses.variableDebtTokenAddress;

  const stakedAaveEncodedInitialize = newStakedAaveImpl.interface.encodeFunctionData('initialize', [
    ghoVariableDebtTokenAddress,
  ]);

  const upgradeTx = await stkAaveProxy.upgradeToAndCall(
    newStakedAaveImpl.address,
    stakedAaveEncodedInitialize
  );
  await upgradeTx.wait();

  console.log(`stkAave upgradeTx.hash: ${upgradeTx.hash}`);
  console.log(`StkAave implementation set to: ${newStakedAaveImpl.address}`);
});
