import { DeployFunction } from 'hardhat-deploy/types';
import { getPool } from '@aave/deploy-v3/dist/helpers/contract-getters';
import { ZERO_ADDRESS } from '../src/helpers/constants';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const pool = await getPool();

  const stableDebtResult = await deploy('GhoStableDebtToken', {
    from: deployer,
    args: [pool.address],
    log: true,
  });
  const stableDebtImpl = await hre.ethers.getContract('GhoStableDebtToken');
  const initializeTx = await stableDebtImpl.initialize(
    pool.address, // initializingPool
    ZERO_ADDRESS, // underlyingAsset
    ZERO_ADDRESS, // incentivesController
    0, // debtTokenDecimals
    'GHO_STABLE_DEBT_TOKEN_IMPL', // debtTokenName
    'GHO_STABLE_DEBT_TOKEN_IMPL', // debtTokenSymbol
    0 // params
  );
  await initializeTx.wait();

  console.log(`Stable Debt Implementation:    ${stableDebtResult.address}`);
  return true;
};

func.id = 'GhoStableDebt';
func.tags = ['GhoStableDebt', 'full_gho_deploy'];

export default func;
