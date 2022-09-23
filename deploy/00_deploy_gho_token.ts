import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  console.log();
  console.log(`~~~~~~~   Beginning GHO Deployments   ~~~~~~~`);

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ghoResult = await deploy('GhoToken', {
    from: deployer,
    args: [[], []],
  });
  console.log(`GHO Address:                   ${ghoResult.address}`);

  const gho = await hre.ethers.getContract('GhoToken');
  const transferOwnershipTx = await gho.transferOwnership(aaveMarketAddresses.shortExecutor);
  await transferOwnershipTx.wait();

  console.log(`GHO ownership transferred to:  ${aaveMarketAddresses.shortExecutor}`);

  return true;
};

func.id = 'GhoToken';
func.tags = ['GhoToken', 'full_gho_deploy'];

export default func;
