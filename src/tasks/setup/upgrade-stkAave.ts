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

task('upgrade-stkAave', 'Upgrade Staked Aave')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;

    const network = getNetwork();
    const { stkAave, shortExecutor } = aaveMarketAddresses[network];

    const [_deployer] = await hre.ethers.getSigners();

    let gho;
    let aaveDataProvider;
    let newStakedAaveImpl;
    let stkAaveProxy;

    // get contracts
    if (params.deploying) {
      gho = await ethers.getContract('GhoToken');
      aaveDataProvider = await getAaveProtocolDataProvider();
      newStakedAaveImpl = await ethers.getContract('StakedTokenV2Rev4Impl');
    } else {
      const contracts = require('../../../contracts.json');

      gho = await getGhoToken(contracts.GhoToken);
      aaveDataProvider = await getAaveProtocolDataProvider(contracts['PoolDataProvider-Test']);
      newStakedAaveImpl = await getStakedAave(contracts.StakedTokenV2Rev4);
    }

    stkAaveProxy = (await getBaseImmutableAdminUpgradeabilityProxy(stkAave)).connect(
      _deployer
    ) as BaseImmutableAdminUpgradeabilityProxy;

    const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
    let ghoVariableDebtTokenAddress = tokenProxyAddresses.variableDebtTokenAddress;

    const stakedAaveEncodedInitialize = newStakedAaveImpl.interface.encodeFunctionData(
      'initialize',
      [ghoVariableDebtTokenAddress]
    );

    const upgradeTx = await stkAaveProxy
      .connect(await impersonateAccountHardhat(shortExecutor))
      .upgradeToAndCall(newStakedAaveImpl.address, stakedAaveEncodedInitialize);
    await upgradeTx.wait();

    console.log(`stkAave upgradeTx.hash: ${upgradeTx.hash}`);
    console.log(`StkAave implementation set to: ${newStakedAaveImpl.address}`);
  });
