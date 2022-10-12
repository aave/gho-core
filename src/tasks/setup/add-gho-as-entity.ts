import { task } from 'hardhat/config';
import { DRE, impersonateAccountHardhat } from '../../helpers/misc-utils';
import { ghoEntityConfig } from '../../helpers/config';
import { IGhoToken } from '../../../types/src/contracts/gho/interfaces/IGhoToken';
import { getAaveProtocolDataProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { getGhoToken } from '../../helpers/contract-getters';

task('add-gho-as-entity', 'Adds Aave as a gho entity')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');
    const { ethers } = DRE;

    let gho;
    let aaveDataProvider;
    let ghoATokenAddress;

    // get contracts
    if (params.deploying) {
      gho = await ethers.getContract('GhoToken');
      aaveDataProvider = await getAaveProtocolDataProvider();
    } else {
      const contracts = require('../../../contracts.json');

      gho = await getGhoToken(contracts.GhoToken);
      aaveDataProvider = await getAaveProtocolDataProvider(contracts['PoolDataProvider-Test']);
    }
    const tokenProxyAddresses = await aaveDataProvider.getReserveTokensAddresses(gho.address);
    ghoATokenAddress = tokenProxyAddresses.aTokenAddress;

    // const network = getNetwork();
    // const { shortExecutor } = aaveMarketAddresses[network];
    // const governanceSigner = await impersonateAccountHardhat(shortExecutor);

    const [_deployer] = await hre.ethers.getSigners();

    gho = await gho.connect(_deployer);

    const aaveEntity: IGhoToken.FacilitatorStruct = {
      label: ghoEntityConfig.label,
      bucket: {
        maxCapacity: ghoEntityConfig.mintLimit,
        level: 0,
      },
    };

    const addEntityTx = await gho.addFacilitators([ghoATokenAddress], [aaveEntity]);
    const addEntityTxReceipt = await addEntityTx.wait();

    let error = false;
    if (addEntityTxReceipt && addEntityTxReceipt.events) {
      const newEntityEvents = addEntityTxReceipt.events.filter(
        (e) => e.event === 'FacilitatorAdded'
      );
      if (newEntityEvents.length > 0) {
        console.log(
          `Address added as a facilitator: ${JSON.stringify(newEntityEvents[0].args[0])}`
        );
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
