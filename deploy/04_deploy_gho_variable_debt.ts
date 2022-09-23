import { DeployFunction } from 'hardhat-deploy/types';
import { getPool } from '@aave/deploy-v3/dist/helpers/contract-getters';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const pool = await getPool();

  const variableDebtImplementation = await deploy('GhoVariableDebtToken', {
    from: deployer,
    args: [pool.address],
  });

  console.log(`Variable Debt Implementation:  ${variableDebtImplementation.address}`);
  return true;
};

func.id = 'GhoVariableDebt';
func.tags = ['GhoVariableDebt', 'full_gho_deploy'];

export default func;
