// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Strings.sol';

library AccessControlErrorsLib {
  function MISSING_ROLE(bytes32 role, address account) external pure returns (bytes memory) {
    return
      abi.encodePacked(
        'AccessControl: account ',
        Strings.toHexString(account),
        ' is missing role ',
        Strings.toHexString(uint256(role), 32)
      );
  }

  function test_coverage_ignore() public {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }
}

library OwnableErrorsLib {
  function CALLER_NOT_OWNER() external pure returns (bytes memory) {
    return abi.encodePacked('Ownable: caller is not the owner');
  }

  function test_coverage_ignore() public {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }
}
