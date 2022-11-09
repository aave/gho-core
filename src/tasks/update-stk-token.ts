import { task } from 'hardhat/config';
import { DRE, setDRE } from '../helpers/misc-utils';

import { AaveProtocolDataProvider__factory, GhoVariableDebtToken__factory } from '../../types';

task(`update-stk-token`, `update GhoAToken stkToken`).setAction(async (_, _DRE) => {
  console.log(`Current Block Number: ${await _DRE.ethers.provider.getBlockNumber()}`);

  const [deployer] = await _DRE.ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  // console.log(`Deploy address: ${deployerAddress}`);

  // const deployerBalance = await _DRE.ethers.provider.getBalance(deployerAddress);
  // console.log(`Deploy balance: ${deployerBalance}`);

  // const aaveProtocolDataProviderFactory = new AaveProtocolDataProvider__factory(deployer);
  // const aaveProtocolDataProvider = await aaveProtocolDataProviderFactory.attach(
  //   '0x77e6b1A75471655067DA3D942A33fE8a9A380fbe'
  // );

  // const tokenAddresses = await aaveProtocolDataProvider.getReserveTokensAddresses(
  //   '0xA48DdCca78A09c37b4070B3E210D6e0234911549'
  // );

  // const ghoVariableDebtTokenFactory = new GhoVariableDebtToken__factory(deployer);
  // const ghoVariableDebtToken = await ghoVariableDebtTokenFactory.attach(
  //   tokenAddresses.variableDebtTokenAddress
  // );

  // console.log(`Initial Discount Token: ${await ghoVariableDebtToken.getDiscountToken()}`);

  // const populatedTx = await ghoVariableDebtToken.populateTransaction.updateDiscountToken(
  //   '0x3eF3dcB6237963abbD20B1A67916784fcF9807f4'
  // );

  // populatedTx.nonce = 499;

  const tx = await deployer.sendTransaction({
    to: deployerAddress,
    nonce: 501,
  });

  console.log(`tx hash: ${tx.hash}`);
  await tx.wait();
  console.log(`tx nonce: ${tx.nonce}`);

  // console.log(`Updated Discount Token: ${await ghoVariableDebtToken.getDiscountToken()}`);
});
