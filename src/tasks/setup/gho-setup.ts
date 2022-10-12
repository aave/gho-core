import { task } from 'hardhat/config';

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

    /*****************************************
     *              CONFIGURE GHO            *
     * 1. Add aave as an GHO entity          *
     * 2. Set addresses in AToken and VDebt  *
     ******************************************/
    blankSpace();
    await hre.run('add-gho-as-entity', { deploying: params.deploying });

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
