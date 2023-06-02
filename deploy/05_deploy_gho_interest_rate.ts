import { DeployFunction } from 'hardhat-deploy/types';
import { ghoReserveConfig } from '../helpers/config';
import { getPoolAddressesProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { INTEREST_RATE } = ghoReserveConfig;

  const addressesProvider = await getPoolAddressesProvider();

  const interestRateStrategy = await deploy('GhoInterestRateStrategy', {
    from: deployer,
    args: [
      addressesProvider.address, // addressesProvider
      INTEREST_RATE, // variableBorrowRate
    ],
    log: true,
  });

  console.log(`Interest Rate Strategy:        ${interestRateStrategy.address}`);
  return true;
};

func.id = 'GhoInterestRateStrategy';
func.tags = ['GhoInterestRateStrategy', 'full_gho_deploy'];

export default func;
