import { DeployFunction } from 'hardhat-deploy/types';
import { getPool } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { ZERO_ADDRESS } from '../helpers/constants';
import { GhoAToken } from '../types';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const pool = await getPool();

  const aTokenResult = await deploy('GhoAToken', {
    from: deployer,
    args: [pool.address],
    log: true,
  });
  const aTokenImpl = (await hre.ethers.getContract('GhoAToken')) as GhoAToken;
  const initializeTx = await aTokenImpl.initialize(
    pool.address, // initializingPool
    ZERO_ADDRESS, // treasury
    ZERO_ADDRESS, // underlyingAsset
    ZERO_ADDRESS, // incentivesController
    0, // aTokenDecimals
    'GHO_ATOKEN_IMPL', // aTokenName
    'GHO_ATOKEN_IMPL', // aTokenSymbol
    '0x10' // params
  );
  await initializeTx.wait();

  console.log(`AToken Implementation:         ${aTokenResult.address}`);
  return true;
};

func.id = 'GhoAToken';
func.tags = ['GhoAToken', 'full_gho_deploy'];

export default func;
