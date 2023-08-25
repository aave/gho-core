import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { getPoolAddressesProvider } from '@aave/deploy-v3';
import { getGhoToken } from '../helpers/contract-getters';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const addressesProvider = await getPoolAddressesProvider();
  const ghoToken = await getGhoToken();

  const ghoSteward = await deploy('GhoSteward', {
    from: deployer,
    args: [addressesProvider.address, ghoToken.address, deployer, deployer],
    log: true,
  });
  console.log(`GHO Steward:               ${ghoSteward.address}`);

  return true;
};

func.id = 'GhoSteward';
func.tags = ['GhoSteward', 'full_gho_deploy'];

export default func;
