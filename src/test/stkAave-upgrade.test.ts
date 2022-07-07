import { expect } from 'chai';
import { helperAddresses } from '../helpers/config';
import { DRE, advanceTimeAndBlock } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { distributeErc20 } from './helpers/user-setup';

makeSuite('Check upgraded stkAave', (testEnv: TestEnv) => {
  let ethers;

  let user1Address;
  let user2Address;

  let user1Signer;
  let user2Signer;

  let amountTransferred;

  before(async () => {
    ethers = DRE.ethers;
    const { users } = testEnv;

    user1Address = users[0].address;
    user1Signer = users[0].signer;

    user2Address = users[1].address;
    user2Signer = users[1].signer;

    await distributeErc20(
      testEnv.stakedAave,
      helperAddresses.stkAaveWhale,
      [user1Address, user2Address],
      ethers.utils.parseUnits('1.0', 18)
    );

    await distributeErc20(
      testEnv.aaveToken,
      helperAddresses.aaveWhale,
      [user1Address, user2Address],
      ethers.utils.parseUnits('1.0', 18)
    );

    amountTransferred = ethers.utils.parseUnits('1.0', 18);
  });

  it('Revision number check', async function () {
    const { stakedAave } = testEnv;

    const revision = await stakedAave.REVISION();

    expect(revision).to.be.equal(4);
  });

  it('GhoDebtToken Address check', async function () {
    const { stakedAave, variableDebtToken } = testEnv;

    let ghoDebtToken = await stakedAave.ghoDebtToken();

    expect(ghoDebtToken).to.be.equal(variableDebtToken.address);
  });

  it('Users should be able to stake AAVE', async () => {
    const { stakedAave, aaveToken } = testEnv;
    const amount = ethers.utils.parseUnits('1.0', 18);
    await aaveToken.connect(user1Signer).approve(stakedAave.address, amount);
    await expect(stakedAave.connect(user1Signer).stake(user1Address, amount))
      .to.emit(stakedAave, 'Staked')
      .withArgs(user1Address, user1Address, amount);
  });

  it('Users should be able to redeem stkAave', async () => {
    const { stakedAave } = testEnv;
    const amount = ethers.utils.parseUnits('1.0', 18);

    await advanceTimeAndBlock(48600);

    await stakedAave.connect(user1Signer).cooldown();

    const COOLDOWN_SECONDS = await stakedAave.COOLDOWN_SECONDS();
    await advanceTimeAndBlock(Number(COOLDOWN_SECONDS.toString()));

    await expect(stakedAave.connect(user1Signer).redeem(user1Address, amount))
      .to.emit(stakedAave, 'Redeem')
      .withArgs(user1Address, user1Address, amount);
  });
});
