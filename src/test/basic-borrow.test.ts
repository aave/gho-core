import { expect } from 'chai';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { DRE } from '../helpers/misc-utils';

makeSuite('Antei VariableDebtToken End-To-End', (testEnv: TestEnv) => {
  let ethers;

  let collateralAmount;
  let borrowAmount;

  before(() => {
    ethers = DRE.ethers;

    collateralAmount = ethers.utils.parseUnits('1000.0', 18);
    borrowAmount = ethers.utils.parseUnits('1000.0', 18);
  });

  it('Deposit WETH and Borrow ASD', async function () {
    const { pool, weth, asd, users } = testEnv;

    const userAddress = users[0].address;
    const userSigner = users[0].signer;

    await weth.connect(userSigner).approve(pool.address, collateralAmount);
    await pool.connect(userSigner).deposit(weth.address, collateralAmount, userAddress, 0);
    await pool.connect(userSigner).borrow(asd.address, borrowAmount, 2, 0, userAddress);

    expect(await asd.balanceOf(userAddress)).to.be.equal(borrowAmount);
  });

  // it('Check interest after 1 year', async function () {});

  // it('Borrow more ASD', async function () {});

  // it('Check users balance from interest', async function () {});
});
