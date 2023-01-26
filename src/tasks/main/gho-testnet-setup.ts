import { task } from 'hardhat/config';

/** NOTICE: This task covers the testnet deployment environment */

task('gho-testnet-setup', 'Deploy and Configure Gho').setAction(async (params, hre) => {
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

  /******************************************
   *              CONFIGURE GHO             *
   * 1. Add aave as a GHO entity            *
   * 2. Add flashminter as GHO entity       *
   * 3. Set addresses in AToken and VDebt   *
   ******************************************/
  blankSpace();

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

  await hre.run('print-all-deployments');
});

const blankSpace = () => {
  console.log();
};
