import { DeployFunction } from 'hardhat-deploy/types';
import { getPool } from '@aave/deploy-v3/dist/helpers/contract-getters';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const pool = await getPool();

  const stableDebtImplementation = await deploy('StableDebtToken', {
    from: deployer,
    args: [pool.address],
  });

  console.log(`Stable Debt Implementation:    ${stableDebtImplementation.address}`);
  return true;
};

func.id = 'GhoStableDebt';
func.tags = ['GhoStableDebt', 'full_gho_deploy'];

export default func;
