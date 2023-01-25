import { expect } from 'chai';
import { advanceTimeAndBlock } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';

makeSuite('Check upgraded stkAave', (testEnv: TestEnv) => {
  let ethers;

  let amountTransferred;

  before(async () => {
    ethers = hre.ethers;
    const {} = testEnv;

    amountTransferred = ethers.utils.parseUnits('1.0', 18);
  });

  it('Revision number check', async function () {
    const { stakedAave } = testEnv;

    const revision = await stakedAave.REVISION();
    const expectedRevision = 4;

    expect(revision).to.be.equal(expectedRevision);
  });

  it('GhoDebtToken Address check', async function () {
    const { stakedAave, variableDebtToken } = testEnv;

    let ghoDebtToken = await stakedAave.ghoDebtToken();

    expect(ghoDebtToken).to.be.equal(variableDebtToken.address);
  });

  it('Users should be able to stake AAVE', async () => {
    const { stakedAave, aaveToken, users } = testEnv;
    const amount = ethers.utils.parseUnits('1.0', 18);
    const approveAmount = ethers.utils.parseUnits('1.0', 18);
    await aaveToken.connect(users[2].signer).approve(stakedAave.address, approveAmount);

    await expect(stakedAave.connect(users[2].signer).stake(users[2].address, amount))
      .to.emit(stakedAave, 'Staked')
      .withArgs(users[2].address, users[2].address, amount);
  });

  it('Users should be able to redeem stkAave', async () => {
    const { stakedAave, users } = testEnv;
    const amount = ethers.utils.parseUnits('1.0', 18);

    await advanceTimeAndBlock(48600);

    await stakedAave.connect(users[2].signer).cooldown();

    const COOLDOWN_SECONDS = await stakedAave.COOLDOWN_SECONDS();
    await advanceTimeAndBlock(Number(COOLDOWN_SECONDS.toString()));

    await expect(stakedAave.connect(users[2].signer).redeem(users[2].address, amount))
      .to.emit(stakedAave, 'Redeem')
      .withArgs(users[2].address, users[2].address, amount);
  });
});
