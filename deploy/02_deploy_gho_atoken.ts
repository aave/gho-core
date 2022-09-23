import { DeployFunction } from 'hardhat-deploy/types';
import { getPool } from '@aave/deploy-v3/dist/helpers/contract-getters';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const pool = await getPool();

  const aTokenImplementation = await deploy('GhoAToken', {
    from: deployer,
    args: [pool.address],
  });

  console.log(`AToken Implementation:         ${aTokenImplementation.address}`);
  return true;
};

func.id = 'GhoAToken';
func.tags = ['GhoAToken', 'full_gho_deploy'];

export default func;
