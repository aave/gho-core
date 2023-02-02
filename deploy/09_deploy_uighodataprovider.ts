import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { getGhoToken } from '../src/helpers/contract-getters';
import { getPoolAddressesProvider } from '@aave/deploy-v3';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ghoToken = await getGhoToken();
  const addressesProvider = await getPoolAddressesProvider();
  const pool = await addressesProvider.getPool();

  const uiGhoDataProviderResult = await deploy('UiGhoDataProvider', {
    from: deployer,
    args: [pool, ghoToken.address],
  });
  console.log(`UiGhoDataProvider:             ${uiGhoDataProviderResult.address}`);

  return true;
};

func.id = 'UiGhoDataProvider';
func.tags = ['UiGhoDataProvider', 'full_gho_deploy'];

export default func;
