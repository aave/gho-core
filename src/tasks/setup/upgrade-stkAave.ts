import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import {
  getBaseImmutableAdminUpgradeabilityProxy,
  getStakedAave,
  getGhoToken,
} from '../../helpers/contract-getters';
import { getAaveProtocolDataProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { getNetwork } from '../../helpers/misc-utils';
import {
  BaseImmutableAdminUpgradeabilityProxy,
  IAaveDistributionManager__factory,
} from '../../../types';
import { getProxyAdminBySlot, STAKE_AAVE_PROXY } from '@aave/deploy-v3';

task('upgrade-stkAave', 'Upgrade Staked Aave')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;
    const network = getNetwork();
    const [_deployer] = await hre.ethers.getSigners();
    let { stkAave } = aaveMarketAddresses[network];
    let gho;
    let aaveDataProvider;
    let newStakedAaveImpl;


    // get contracts
    if (params.deploying) {
      gho = await ethers.getContract('GhoToken');
      aaveDataProvider = await getAaveProtocolDataProvider();
      newStakedAaveImpl = await ethers.getContract('StakedTokenV2Rev4Impl');
      stkAave = (await hre.deployments.get(STAKE_AAVE_PROXY)).address
    } else {
      const contracts = require('../../../contracts.json');

      gho = await getGhoToken(contracts.GhoToken);
      aaveDataProvider = await getAaveProtocolDataProvider(contracts['PoolDataProvider-Test']);
      newStakedAaveImpl = await getStakedAave(contracts.StakedTokenV2Rev4);
    }

    const stkAaveProxy = (await getBaseImmutableAdminUpgradeabilityProxy(stkAave)).connect(
      _deployer
    ) as BaseImmutableAdminUpgradeabilityProxy;

    const admin = await getProxyAdminBySlot(stkAave);

    const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
    let ghoVariableDebtTokenAddress = tokenProxyAddresses.variableDebtTokenAddress;

    const stakedAaveEncodedInitialize = newStakedAaveImpl.interface.encodeFunctionData(
      'initialize',
      [ghoVariableDebtTokenAddress]
    );

    const upgradeTx = await stkAaveProxy
      .connect(await impersonateAccountHardhat(admin))
      .upgradeToAndCall(newStakedAaveImpl.address, stakedAaveEncodedInitialize);
    await upgradeTx.wait();

    console.log(`stkAave upgradeTx.hash: ${upgradeTx.hash}`);
    console.log(`StkAave implementation set to: ${newStakedAaveImpl.address}`);
  });
