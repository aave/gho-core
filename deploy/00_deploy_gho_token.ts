import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { getNetwork } from '../src/helpers/misc-utils';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  console.log();
  console.log(`~~~~~~~   Beginning GHO Deployments   ~~~~~~~`);

  const [_deployer, ...restSigners] = await hre.ethers.getSigners();

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ghoResult = await deploy('GhoToken', {
    from: deployer,
    args: [[], []],
  });
  console.log(`GHO Address:                   ${ghoResult.address}`);

  const network = getNetwork();
  const { shortExecutor } = aaveMarketAddresses[network];

  const gho = await hre.ethers.getContract('GhoToken');
  const transferOwnershipTx = await gho.transferOwnership(shortExecutor);
  await transferOwnershipTx.wait();

  console.log(`GHO ownership transferred to:  ${shortExecutor}`);

  return true;
};

func.id = 'GhoToken';
func.tags = ['GhoToken', 'full_gho_deploy'];

export default func;
