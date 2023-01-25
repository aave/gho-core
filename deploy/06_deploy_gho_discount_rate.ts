import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const discountRateStrategy = await deploy('GhoDiscountRateStrategy', {
    from: deployer,
    args: [],
    log: true,
  });

  console.log(`Discount Rate Strategy:        ${discountRateStrategy.address}`);
  return true;
};

func.id = 'GhoDiscountRateStrategy';
func.tags = ['GhoDiscountRateStrategy', 'full_gho_deploy'];

export default func;
