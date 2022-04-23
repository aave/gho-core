import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/aave-v2-addresses';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { pool, treasury, incentivesController } = aaveMarketAddresses;
  const asd = await hre.ethers.getContract('AnteiStableDollarEntities');

  const variableDebtImplementation = await deploy('VariableDebtToken', {
    from: deployer,
    args: [pool, asd.address, 'Antei Stable Dollar', 'ASD', incentivesController],
  });

  console.log(`Variable Debt Implementation:  ${variableDebtImplementation.address}`);
  return true;
};

func.id = 'AnteiVariableDebt';
func.tags = ['AnteiVariableDebt', 'full_antei_deploy'];

export default func;
