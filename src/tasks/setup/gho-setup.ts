import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';

task('gho-setup', 'Deploy and Configure Gho').setAction(async (_, hre) => {
  await hre.run('set-DRE');
  const { deployments, ethers } = DRE;

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
   * 1. Add aave as a GHO entity          *
   * 2. Add flashminter as GHO entity
   * 2. Set addresses in AToken and VDebt  *
   ******************************************/
  blankSpace();
  await hre.run('add-gho-as-entity');

  blankSpace();
  await hre.run('add-gho-flashminter-as-entity');

  blankSpace();
  await hre.run('set-gho-addresses');

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
