import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/aave-v2-addresses';
import { asdConfiguration } from '../src/configs/asd-configuration';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { INTEREST_RATE } = asdConfiguration.marketConfig;

  const intrestRateStrategy = await deploy('AnteiInterestRateStrategy', {
    from: deployer,
    args: [
      aaveMarketAddresses.addressesProvider, // provider
      0, // optimalUsageRatio
      INTEREST_RATE, // baseVariableBorrowRate
      0, // variableRateSlope1
      0, // variableRateSlope2
      0, // stableRateSlope1
      0, // stableRateSlope2
    ],
  });

  console.log(`Interest Rate Strategy:        ${intrestRateStrategy.address}`);
  return true;
};

func.id = 'AnteiInterestRateStrategy';
func.tags = ['AnteiInterestRateStrategy', 'full_antei_deploy'];

export default func;
