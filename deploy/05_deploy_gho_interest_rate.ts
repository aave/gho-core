import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { ghoReserveConfig } from '../src/helpers/config';
import { getPoolAddressesProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { INTEREST_RATE } = ghoReserveConfig;

  const addressesProvider = await getPoolAddressesProvider();

  const intrestRateStrategy = await deploy('GhoInterestRateStrategy', {
    from: deployer,
    args: [
      addressesProvider.address, // provider
      0, // optimalUsageRatio
      INTEREST_RATE, // baseVariableBorrowRate
      0, // variableRateSlope1
      0, // variableRateSlope2
      0, // stableRateSlope1
      0, // stableRateSlope2
      0, // uint256 baseStableRateOffset,
      0, // uint256 stableRateExcessOffset,
      0, // uint256 optimalStableToTotalDebtRatio
    ],
  });

  console.log(`Interest Rate Strategy:        ${intrestRateStrategy.address}`);
  return true;
};

func.id = 'GhoInterestRateStrategy';
func.tags = ['GhoInterestRateStrategy', 'full_gho_deploy'];

export default func;
