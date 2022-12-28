import { DeployFunction } from 'hardhat-deploy/types';
import { aaveMarketAddresses } from '../src/helpers/config';
import { getNetwork } from '../src/helpers/misc-utils';

const func: DeployFunction = async function ({ getNamedAccounts, deployments, ...hre }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const network = getNetwork();
  const { rewardsVault, emissionManager } = aaveMarketAddresses[network];

  const aaveArtifact = await deployments.get('AAVE-TestnetMintableERC20-Test');

  const stakedAaveImpl = await deploy('StakedTokenV2Rev4Impl', {
    from: deployer,
    contract: 'StakedTokenV2Rev4',
    args: [
      aaveArtifact.address,
      aaveArtifact.address,
      '864000',
      '172800',
      rewardsVault,
      emissionManager,
      '3153600000', // 100 years from the time of deployment
      'Staked AAVE',
      'stkAAVE',
      '18',
      '0x0000000000000000000000000000000000000000',
    ],
    log: true,
  });
  console.log(`stakedAaveImpl Logic:         ${stakedAaveImpl.address}`);

  const contracts = await deployments.all();
  const printableContracts = {};
  Object.keys(contracts).forEach((contract) => {
    printableContracts[contract] = contracts[contract].address;
  });
  require('fs').writeFile(
    'contracts.json',
    JSON.stringify(printableContracts, null, 2),
    (error) => {
      if (error) {
        throw error;
      }
    }
  );
};

func.id = 'StkAaveUpgrade';
func.tags = ['StkAaveUpgrade', 'full_gho_deploy'];

export default func;
