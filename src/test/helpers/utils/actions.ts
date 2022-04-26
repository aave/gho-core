import { BigNumber } from 'ethers';
import { tEthereumAddress } from '../../../helpers/types';
import { TestEnv } from '../../helpers/make-suite';
import { getReserveData, getUserData, expectEqual } from '../../helpers/utils/helpers';
import {
  calcExpectedReserveDataAfterBorrow,
  calcExpectedUserDataAfterBorrow,
  calcExpectedReserveDataAfterRepay,
  calcExpectedUserDataAfterRepay,
} from '../../helpers/math/calculations';
import {
  timeLatest,
  getReceiptAndTimestamp,
  impersonateAccountHardhat,
  advanceTimeAndBlock,
} from '../../../helpers/misc-utils';

export const borrowASD = async (
  userAddress: tEthereumAddress,
  borrowAmount: BigNumber,
  secondsToJump: number,
  testEnv: TestEnv
) => {
  const { asd, pool } = testEnv;
  const userSigner = await impersonateAccountHardhat(userAddress);
  const reserveDataBefore = await getReserveData(asd.address, testEnv);
  const userDataBefore = await getUserData(userAddress, testEnv);

  const [_, timestamp] = await getReceiptAndTimestamp(
    await pool.connect(userSigner).borrow(asd.address, borrowAmount, 2, 0, userAddress)
  );

  if (secondsToJump > 0) {
    await advanceTimeAndBlock(secondsToJump);
  }

  const reserveDataAfter = await getReserveData(asd.address, testEnv);
  const userDataAfter = await getUserData(userAddress, testEnv);

  const expectedReserveData = await calcExpectedReserveDataAfterBorrow(
    borrowAmount,
    reserveDataBefore,
    timestamp,
    await timeLatest()
  );
  const expectedUserData = await calcExpectedUserDataAfterBorrow(
    borrowAmount,
    reserveDataBefore,
    expectedReserveData,
    userDataBefore,
    await timeLatest()
  );

  expectEqual(reserveDataAfter, expectedReserveData);
  expectEqual(userDataAfter, expectedUserData);
};

export const repayASD = async (
  amountToRepay: BigNumber,
  userAddress: tEthereumAddress,
  onBehalfOf: tEthereumAddress,
  testEnv: TestEnv
): Promise<BigNumber> => {
  const { pool, asd } = testEnv;

  const userSigner = await impersonateAccountHardhat(userAddress);

  const reserveDataBefore = await getReserveData(asd.address, testEnv);
  const userDataBefore = await getUserData(onBehalfOf, testEnv);

  const [_, timestamp] = await getReceiptAndTimestamp(
    await pool.connect(userSigner).repay(asd.address, amountToRepay, 2, onBehalfOf)
  );

  const reserveDataAfter = await getReserveData(asd.address, testEnv);
  const userDataAfter = await getUserData(userAddress, testEnv);

  const expectedReserveData = calcExpectedReserveDataAfterRepay(
    amountToRepay,
    reserveDataBefore,
    userDataBefore,
    timestamp
  );

  const [totalRepaid, expectedUserData] = calcExpectedUserDataAfterRepay(
    amountToRepay,
    reserveDataBefore,
    expectedReserveData,
    userDataBefore,
    userAddress,
    onBehalfOf,
    timestamp,
    await timeLatest()
  );

  expectEqual(reserveDataAfter, expectedReserveData);
  expectEqual(userDataAfter, expectedUserData);

  return totalRepaid;
};
