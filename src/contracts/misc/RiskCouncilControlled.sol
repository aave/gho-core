// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract RiskCouncilControlled {
  address public immutable COUNCIL;

  constructor(address riskCouncil) {
    require(riskCouncil != address(0), 'INVALID_RISK_COUNCIL');
    COUNCIL = riskCouncil;
  }

  /**
   * @dev Only Risk Council can call functions marked by this modifier.
   */
  modifier onlyRiskCouncil() {
    require(COUNCIL == msg.sender, 'INVALID_CALLER');
    _;
  }
}
