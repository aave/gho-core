import rawBRE from 'hardhat';
import { initializeMakeSuite } from './helpers/make-suite';

before(async () => {
  await rawBRE.run('antei-setup');
  console.log('-> Antei Configured');

  console.log('-> Initializing test enviroment');
  await initializeMakeSuite();
  console.log('\n***************');
  console.log('Setup and snapshot finished');
  console.log('***************\n');
});
