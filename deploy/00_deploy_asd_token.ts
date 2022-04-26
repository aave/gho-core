import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { asdTokenConfig } from '../src/helpers/config';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const { TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS } = asdTokenConfig;

  const asdResult = await deploy('AnteiStableDollarEntities', {
    from: deployer,
    args: [[], [], TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS],
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
