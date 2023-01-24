import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses, ghoEntityConfig } from '../src/helpers/config';
import { getGhoToken } from '../src/helpers/contract-getters';
import { TREASURY_PROXY_ID, getPoolAddressesProvider, getTreasuryAddress } from '@aave/deploy-v3';
import { getNetwork } from '../src/helpers/misc-utils';

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ghoToken = await getGhoToken();
  const addressesProvider = await getPoolAddressesProvider();
  const treasury = (await deployments.get(TREASURY_PROXY_ID)).address;
  const network = getNetwork();

  // flash fee 100 = 1.00%
  const flashFee = ghoEntityConfig.flashMinterFee;

  const ghoFlashMinterResult = await deploy('GhoFlashMinter', {
    from: deployer,
    args: [ghoToken.address, treasury, flashFee, addressesProvider.address],
    log: true,
  });
  console.log(`GHO FlashMinter:               ${ghoFlashMinterResult.address}`);

  return true;
};

func.id = 'GhoFlashMinter';
func.tags = ['GhoFlashMinter', 'full_gho_deploy'];

export default func;
