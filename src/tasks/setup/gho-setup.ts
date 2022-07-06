import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/config';
import { getAaveOracle, getLendingPoolConfigurator } from '../../helpers/contract-getters';

task('gho-setup', 'Deploy and Configure Gho').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { deployments, ethers } = DRE;

  /*****************************************
   *        DEPLOY DEPENDENT CONTRACTS     *
   ******************************************/

  if (hre.network.name === 'hardhat') {
    await deployments.fixture(['full_gho_deploy']);
  } else {
    console.log('Contracts already deployed!');
  }

  /*****************************************
   *          INITIALIZE RESERVE           *
   ******************************************/
  blankSpace();
  await hre.run('initialize-gho-reserve');

  /*****************************************
   *          CONFIGURE RESERVE            *
   * 1. enable borrowing                   *
   * 2. configure oracle                   *
   ******************************************/
  blankSpace();
  await hre.run('enable-gho-borrowing');

  blankSpace();
  await hre.run('set-gho-oracle');

  /*****************************************
   *              CONFIGURE GHO            *
   * 1. Add aave as an GHO entity          *
   * 2. Set addresses in AToken and VDebt  *
   ******************************************/
  blankSpace();
  await hre.run('add-gho-as-entity');

  blankSpace();
  await hre.run('set-gho-addresses');

  /*****************************************
   *               UPDATE POOL             *
   ******************************************/
  blankSpace();
  await hre.run('upgrade-pool');

  /*****************************************
   *               UPDATE StkAave          *
   ******************************************/
  blankSpace();
  await hre.run('upgrade-stkAave');

  console.log(`\nGho Setup Complete!\n`);
});

const blankSpace = () => {
  console.log();
};
