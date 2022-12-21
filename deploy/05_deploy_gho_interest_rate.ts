import { DeployFunction } from 'hardhat-deploy/types';
import { ghoReserveConfig } from '../src/helpers/config';
import { getPoolAddressesProvider } from '@aave/deploy-v3/dist/helpers/contract-getters';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { INTEREST_RATE } = ghoReserveConfig;

  const intrestRateStrategy = await deploy('GhoInterestRateStrategy', {
    from: deployer,
    args: [
      INTEREST_RATE, // variableBorrowRate
    ],
  });

  console.log(`Interest Rate Strategy:        ${intrestRateStrategy.address}`);
  return true;
};

func.id = 'GhoInterestRateStrategy';
func.tags = ['GhoInterestRateStrategy', 'full_gho_deploy'];

export default func;
