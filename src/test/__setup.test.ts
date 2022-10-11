import rawBRE from 'hardhat';
import { initializeMakeSuite } from './helpers/make-suite';
import { getPool } from '@aave/deploy-v3/dist/helpers/contract-getters';

before(async () => {
  await rawBRE.deployments.fixture(['market', 'full_gho_deploy']);
  await rawBRE.run('gho-setup');

  console.log('-> Gho Configured');

  console.log('-> Initializing test environment');
  await initializeMakeSuite();

  console.log('\n***************');
  console.log('Setup and snapshot finished');
  console.log('***************\n');
});
