import { DeployFunction } from 'hardhat-deploy/types';
import { getPool } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { getAToken } from '@aave/deploy-v3';
import { ZERO_ADDRESS } from '../src/helpers/constants';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const pool = await getPool();

  const aTokenResult = await deploy('GhoAToken', {
    from: deployer,
    args: [pool.address],
    log: true,
  });
  const aTokenImpl = await hre.ethers.getContract('GhoAToken');
  await aTokenImpl.initialize(
    pool.address, // initializingPool
    ZERO_ADDRESS, // treasury
    ZERO_ADDRESS, // underlyingAsset
    ZERO_ADDRESS, // incentivesController
    0, // aTokenDecimals
    'ATOKEN_IMPL', // aTokenName
    'ATOKEN_IMPL', // aTokenSymbol
    0 // params
  );

  console.log(`AToken Implementation:         ${aTokenResult.address}`);
  return true;
};

func.id = 'GhoAToken';
func.tags = ['GhoAToken', 'full_gho_deploy'];

export default func;
