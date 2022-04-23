import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const asd = await deploy('AnteiStableDollarEntities', {
    from: deployer,
    args: [[]],
  });
  console.log(`ASD Address:                   ${asd.address}`);

  return true;
};

func.id = 'AnteiStableDollarEntities';
func.tags = ['AnteiStableDollarEntities', 'full_antei_deploy'];

export default func;
