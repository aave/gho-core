// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title RiskCouncilControlled
 * @author Aave Labs
 * @notice Helper contract for controlling access to Steward and other functions restricted to Risk Council
 */
abstract contract RiskCouncilControlled {
  address internal immutable _riskCouncil;

  /**
   * @dev Constructor
   * @param riskCouncil The address of the risk council
   */
  constructor(address riskCouncil) {
    require(riskCouncil != address(0), 'INVALID_RISK_COUNCIL');
    _riskCouncil = riskCouncil;
  }

  /**
   * @dev Only Risk Council can call functions marked by this modifier.
   */
  modifier onlyRiskCouncil() {
    require(_riskCouncil == msg.sender, 'INVALID_CALLER');
    _;
  }
}
