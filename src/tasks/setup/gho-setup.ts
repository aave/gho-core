import { task } from 'hardhat/config';
import { isLiveNetwork } from '../../helpers/misc-utils';

task('gho-setup', 'Deploy and Configure Gho')
  .addFlag('deploying', 'true or false contracts are being deployed')
  .setAction(async (params, hre) => {
    await hre.run('set-DRE');

    /*****************************************
     *          INITIALIZE RESERVE           *
     ******************************************/
    blankSpace();
    await hre.run('initialize-gho-reserve', { deploying: params.deploying });

    /*****************************************
     *          CONFIGURE RESERVE            *
     * 1. enable borrowing                   *
     * 2. configure oracle                   *
     ******************************************/
    blankSpace();
    await hre.run('enable-gho-borrowing', { deploying: params.deploying });

    blankSpace();
    await hre.run('set-gho-oracle', { deploying: params.deploying });

    /******************************************
     *              CONFIGURE GHO             *
     * 1. Transfer Ownership of GHO (if live) *
     * 2. Add aave as a GHO entity            *
     * 3. Add flashminter as GHO entity       *
     * 4. Set addresses in AToken and VDebt   *
     ******************************************/
    blankSpace();
    if (isLiveNetwork()) {
      await hre.run('gho-transfer-ownership', { deploying: params.deploying });
    }

    blankSpace();
    await hre.run('add-gho-as-entity', { deploying: params.deploying });

    blankSpace();
    await hre.run('add-gho-flashminter-as-entity', { deploying: params.deploying });

    blankSpace();
    await hre.run('set-gho-addresses', { deploying: params.deploying });

    /*****************************************
     *               UPDATE StkAave          *
     ******************************************/
    blankSpace();
    await hre.run('upgrade-stkAave', { deploying: params.deploying });

    console.log(`\nGho Setup Complete!\n`);
  });

const blankSpace = () => {
  console.log();
};
