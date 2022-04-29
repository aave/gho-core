import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { getAaveOracle, getLendingPoolConfigurator } from '../../helpers/contract-getters';

task('antei-setup', 'Deploy and Configure Antei').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { deployments, ethers } = DRE;

  /*****************************************
   *        DEPLOY DEPENDENT CONTRACTS     *
   ******************************************/

  if (hre.network.name === 'hardhat') {
    await deployments.fixture(['full_antei_deploy']);
  } else {
    console.log('Contracts already deployed!');
  }

  /*****************************************
   *          INITIALIZE RESERVE           *
   ******************************************/
  blankSpace();
  await hre.run('initialize-asd-reserve');

  /*****************************************
   *          CONFIGURE RESERVE            *
   * 1. enable borrowing                   *
   * 2. configure oracle                   *
   ******************************************/
  blankSpace();
  await hre.run('enable-asd-borrowing');

  blankSpace();
  await hre.run('set-asd-oracle');

  /*****************************************
   *              CONFIGURE ASD            *
   * 1. Add aave as an ASD entity          *
   * 2. Set addresses in AToken and VDebt  *
   ******************************************/
  blankSpace();
  await hre.run('add-asd-as-entity');

  blankSpace();
  await hre.run('set-asd-addresses');

  console.log(`\nAntei Setup Complete!\n`);
});

const blankSpace = () => {
  console.log();
};
