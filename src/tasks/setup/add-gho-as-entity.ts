import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { ZERO_ADDRESS } from '../../helpers/constants';
import { aaveMarketAddresses } from '../../helpers/config';
import { getAToken, getAaveProtocolDataProvider } from '../../helpers/contract-getters';
import { GhoToken } from '../../../types/src/contracts/token';
import { ghoEntityConfig } from '../../helpers/config';

task('add-gho-as-entity', 'Adds Aave as a gho entity').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { ethers } = DRE;

  let gho = await ethers.getContract('GhoToken');

  const aaveDataProvider = await getAaveProtocolDataProvider(
    aaveMarketAddresses.aaveProtocolDataProvider
  );

  const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
  const aToken = await getAToken(tokenProxyAddresses.aTokenAddress);
  const variableDebtToken = await getAToken(tokenProxyAddresses.variableDebtTokenAddress);

  const governanceSigner = await impersonateAccountHardhat(aaveMarketAddresses.shortExecutor);
  gho = await gho.connect(governanceSigner);

  const aaveEntity: GhoToken.InputEntityStruct = {
    label: ghoEntityConfig.label,
    entityAddress: ghoEntityConfig.entityAddress,
    mintLimit: ghoEntityConfig.mintLimit,
    minters: [aToken.address],
    burners: [aToken.address],
    active: true,
  };

  const addEntityTx = await gho.addEntities([aaveEntity]);
  const addEntityTxReceipt = await addEntityTx.wait();

  let error = false;
  if (addEntityTxReceipt && addEntityTxReceipt.events) {
    const newEntityEvents = addEntityTxReceipt.events.filter((e) => e.event === 'EntityCreated');
    if (newEntityEvents.length > 0) {
      console.log(`New Entity Added with ID ${newEntityEvents[0].args.id}`);
    } else {
      error = true;
    }
  } else {
    error = true;
  }
  if (error) {
    console.log(`ERROR: Aave not added as GHO entity`);
  }
});
