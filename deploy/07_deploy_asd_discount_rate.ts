import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const discountRateStrategy = await deploy('AnteiDiscountRateStrategy', {
    from: deployer,
    args: [],
  });

  console.log(`Discount Rate Strategy:        ${discountRateStrategy.address}`);
  return true;
};

func.id = 'AnteiDiscountRateStrategy';
func.tags = ['AnteiDiscountRateStrategy', 'full_antei_deploy'];

export default func;
