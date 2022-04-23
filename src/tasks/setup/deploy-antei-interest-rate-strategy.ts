import { task } from 'hardhat/config';
import { DRE } from '../../helpers/misc-utils';
import { aaveMarketAddresses } from '../../helpers/aave-v2-addresses';

task('deploy-antei-interest-rate-strategy', 'Deploy Antei Interest Rate Strategy')
  .addParam('interestRate')
  .setAction(async ({ interestRate }, hre) => {
    await hre.run('set-DRE');

    const { addressesProvider } = aaveMarketAddresses;

    const anteiInterestRateStrategy_Factory = await DRE.ethers.getContractFactory(
      'AnteiInterestRateStrategy'
    );
    const anteiInterestRateStrategy = await anteiInterestRateStrategy_Factory.deploy(
      addressesProvider, // provider
      0, // optimalUsageRatio
      DRE.ethers.BigNumber.from(interestRate), // baseVariableBorrowRate
      0, // variableRateSlope1
      0, // variableRateSlope2
      0, // stableRateSlope1
      0 // stableRateSlope2
    );

    console.log(`Interest Rate Strategy:        ${anteiInterestRateStrategy.address}`);
    return anteiInterestRateStrategy.address;
  });
