import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/aave-v2-addresses';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const asdResult = await deploy('AnteiStableDollarEntities', {
    from: deployer,
    args: [[]],
  });
  console.log(`ASD Address:                   ${asdResult.address}`);

  const asd = await hre.ethers.getContract('AnteiStableDollarEntities');
  const transferOwnershipTx = await asd.transferOwnership(aaveMarketAddresses.shortExecutor);
  await transferOwnershipTx.wait();

  console.log(`ASD ownership transferred to:  ${aaveMarketAddresses.shortExecutor}`);
  console.log();

  return true;
};

func.id = 'AnteiStableDollarEntities';
func.tags = ['AnteiStableDollarEntities', 'full_antei_deploy'];

export default func;
