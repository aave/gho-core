// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ITransparentProxyFactory {
  /**
   * @notice Creates a transparent proxy instance, doing the first initialization in construction
   * @dev Version using CREATE
   * @param logic The address of the implementation contract
   * @param initialOwner The initial owner of the admin of the proxy.
   * @param data abi encoded call to the function with `initializer` (or `reinitializer`) modifier.
   *             E.g. `abi.encodeWithSelector(mockImpl.initialize.selector, 2)`
   *             for an `initialize` function being `function initialize(uint256 foo) external initializer;`
   * @return address The address of the proxy deployed
   **/
  function create(
    address logic,
    address initialOwner,
    bytes memory data
  ) external returns (address);
}
