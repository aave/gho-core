// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title RiskCouncilControlled
 * @author Aave Labs
 * @notice Helper contract for controlling access to Steward and other functions restricted to Risk Council
 */
abstract contract RiskCouncilControlled {
  address internal immutable riskCouncil;

  /**
   * @dev Constructor
   * @param _riskCouncil The address of the risk council
   */
  constructor(address _riskCouncil) {
    require(_riskCouncil != address(0), 'INVALID_RISK_COUNCIL');
    riskCouncil = _riskCouncil;
  }

  /**
   * @dev Only Risk Council can call functions marked by this modifier.
   */
  modifier onlyRiskCouncil() {
    require(riskCouncil == msg.sender, 'INVALID_CALLER');
    _;
  }
}
