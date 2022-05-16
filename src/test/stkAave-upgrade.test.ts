import { expect } from 'chai';
import { aaveMarketAddresses } from '../helpers/config';
import { DRE, advanceTimeAndBlock } from '../helpers/misc-utils';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { getAToken, getVariableDebtToken } from '../helpers/contract-getters';
import { MAX_UINT_AMOUNT, YEAR } from '../helpers/constants';

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

    amountTransferred = ethers.utils.parseUnits('1.0', 18);
  });

  it('Revision number check', async function () {
    const { stakedAave } = testEnv;

    const revision = await stakedAave.REVISION();

    expect(revision).to.be.equal(4);
  });

  it('AnteiDebtToken Address check', async function () {
    const { stakedAave, variableDebtToken } = testEnv;

    let anteiDebtToken = await stakedAave.anteiDebtToken();

    expect(anteiDebtToken).to.be.equal(variableDebtToken.address);
  });

  it('transfer and check if the required event is emitted in AnteiDebtToken', async function () {
    const { stakedAave, variableDebtToken } = testEnv;

    await expect(stakedAave.connect(user1Signer).transfer(user2Address, amountTransferred)).to.emit(
      variableDebtToken,
      'DistributionUpdated'
    );
  });

  it('Users should be able to stake AAVE', async () => {
    const { stakedAave, aaveToken } = testEnv;
    const amount = ethers.utils.parseUnits('1.0', 18);
    await aaveToken.connect(user1Signer).approve(stakedAave.address, amount);
    await expect(stakedAave.connect(user1Signer).stake(user1Address, amount)).to.emit(
      stakedAave,
      'Staked'
    );
  });

  it('Users should be able to redeem stkAave', async () => {
    const { stakedAave } = testEnv;
    const amount = ethers.utils.parseUnits('1.0', 18);

    await advanceTimeAndBlock(48600);

    await stakedAave.connect(user1Signer).cooldown();

    const COOLDOWN_SECONDS = await stakedAave.COOLDOWN_SECONDS();
    await advanceTimeAndBlock(Number(COOLDOWN_SECONDS.toString()));

    await expect(stakedAave.connect(user1Signer).redeem(user1Address, amount)).to.emit(
      stakedAave,
      'Redeem'
    );
  });
});
