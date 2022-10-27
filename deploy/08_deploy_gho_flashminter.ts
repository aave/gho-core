import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
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

  const ghoFlashMinterResult = await deploy('GhoFlashMinter', {
    from: deployer,
    args: [ghoToken.address, aaveMarketAddresses.treasury, 100, addressesProvider.address],
  });
  console.log(`GHO FlashMinter:               ${ghoFlashMinterResult.address}`);

  return true;
};

func.id = 'GhoFlashMinter';
func.tags = ['GhoFlashMinter', 'full_gho_deploy'];

export default func;
