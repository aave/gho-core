// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from '@openzeppelin/contracts/access/IAccessControl.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

library AccessControlErrorsLib {
  function MISSING_ROLE(bytes32 role, address account) external pure returns (bytes memory) {
    return
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        account,
        role
      );
  }

  function test_coverage_ignore() public {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }
}

library OwnableErrorsLib {
  function CALLER_NOT_OWNER(address caller) external pure returns (bytes memory) {
    return abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller);
  }

  function test_coverage_ignore() public {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }
}
