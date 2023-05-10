import rawBRE from 'hardhat';
import { initializeMakeSuite } from './helpers/make-suite';
import { config } from 'dotenv';
config();

before(async () => {
  const skipDeploy = process.env.SKIP_DEPLOY === 'true';

  if (!skipDeploy) {
    await rawBRE.run('deploy-and-setup');
    console.log('-> Gho deployed and configured');
  } else {
    console.log('-> Testing Gho Market reusing deployments/ artifacts');
  }

  console.log('-> Initializing test environment');
  await initializeMakeSuite();

  console.log('\n***************');
  console.log('Setup and snapshot finished');
  console.log('***************\n');
});
