import rawBRE from 'hardhat';
import { initializeMakeSuite } from './helpers/make-suite';
import { config } from 'dotenv';
config();

before(async () => {
  await rawBRE.run('set-DRE');
  const deploying = process.env.DEPLOYING === 'true' ? true : false;

  if (deploying) {
    await rawBRE.deployments.fixture(['market', 'full_gho_deploy']);
    await rawBRE.run('gho-setup', { deploying: deploying });
    console.log('-> Gho Configured');
  } else {
    console.log('-> Testing Deployed Market');
  }

  console.log('-> Initializing test environment');
  await initializeMakeSuite(deploying);

  console.log('\n***************');
  console.log('Setup and snapshot finished');
  console.log('***************\n');
});
