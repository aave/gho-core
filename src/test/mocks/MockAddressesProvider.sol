// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockAddressesProvider {
  address immutable ACL_MANAGER;
  address POOL;
  address POOL_CONFIGURATOR;

  constructor(address aclManager) {
    ACL_MANAGER = aclManager;
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  function setPool(address pool) public {
    POOL = pool;
  }

  function setConfigurator(address configurator) public {
    POOL_CONFIGURATOR = configurator;
  }

  function getACLManager() public view returns (address) {
    return ACL_MANAGER;
  }

  function getPool() public view returns (address) {
    return POOL;
  }

  function getPoolConfigurator() public view returns (address) {
    return POOL_CONFIGURATOR;
  }
}
