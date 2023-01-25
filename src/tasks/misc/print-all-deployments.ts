import { getWalletBalances } from '@aave/deploy-v3';
import { task } from 'hardhat/config';

task(`print-all-deployments`).setAction(async (_, { deployments, getNamedAccounts, ...hre }) => {
  const allDeployments = await deployments.all();

  let formattedDeployments: { [k: string]: { address: string } } = {};
  let mintableTokens: { [k: string]: { address: string } } = {};

  console.log('\nAccounts after deployment');
  console.log('========');
  console.table(await getWalletBalances());

  // Print deployed contracts
  console.log('\nDeployments');
  console.log('===========');
  Object.keys(allDeployments).forEach((key) => {
    if (!key.includes('Mintable')) {
      formattedDeployments[key] = {
        address: allDeployments[key].address,
      };
    }
  });
  console.table(formattedDeployments);

  // Print Mintable Reserves and Rewards
  Object.keys(allDeployments).forEach((key) => {
    if (key.includes('Mintable')) {
      mintableTokens[key] = {
        address: allDeployments[key].address,
      };
    }
  });
  mintableTokens['GhoToken'] = { address: allDeployments['GhoToken'].address };
  console.log('Reserves');
  console.table(mintableTokens);
});
