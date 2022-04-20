import hre from 'hardhat';
import { expect } from 'chai';
import { DRE } from '../helpers/misc-utils';

describe('Greeter', function () {
  it("Should return the new greeting once it's changed", async function () {
    await hre.run('set-DRE');
    const Greeter = await DRE.ethers.getContractFactory('Greeter');
    const greeter = await Greeter.deploy('Hello, world!');

    await greeter.deployed();
    expect(await greeter.greet()).to.equal('Hello, world!');

    await greeter.setGreeting('Hola, mundo!');
    expect(await greeter.greet()).to.equal('Hola, mundo!');
  });
});
