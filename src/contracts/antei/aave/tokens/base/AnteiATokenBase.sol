// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {ILendingPoolAddressesProvider} from '../../../dependencies/aave-core/interfaces/ILendingPoolAddressesProvider.sol';
import {Errors} from '../../../dependencies/aave-core/protocol/libraries/helpers/Errors.sol';
import {IncentivizedERC20} from '../../../dependencies/aave-tokens/IncentivizedERC20.sol';

import {AnteiVariableDebtToken} from '../AnteiVariableDebtToken.sol';
import {IAnteiATokenBase} from '../interfaces/IAnteiATokenBase.sol';

/**
 * @title AnteiATokenBase
 * @notice Base for the AnteiAToken
 * @author Aave
 **/
abstract contract AnteiATokenBase is IncentivizedERC20, IAnteiATokenBase {
  address public immutable ADDRESSES_PROVIDER;

  AnteiVariableDebtToken internal _anteiVariableDebtToken;
  address internal _anteiTreasury;

  /**
   * @dev Only pool admin can call functions marked by this modifier.
   **/
  modifier onlyLendingPoolAdmin() {
    ILendingPoolAddressesProvider addressesProvider = ILendingPoolAddressesProvider(
      ADDRESSES_PROVIDER
    );
    require(addressesProvider.getPoolAdmin() == msg.sender, Errors.CALLER_NOT_POOL_ADMIN);
    _;
  }

  constructor(
    string memory tokenName,
    string memory tokenSymbol,
    address incentivesController,
    address addressesProvider
  ) public IncentivizedERC20(tokenName, tokenSymbol, 18, incentivesController) {
    ADDRESSES_PROVIDER = addressesProvider;
  }

  function setVariableDebtToken(address anteiVariableDebtAddress)
    external
    override
    onlyLendingPoolAdmin
  {
    require(address(_anteiVariableDebtToken) == address(0), 'VARIABLE_DEBT_TOKEN_ALREADY_SET');
    _anteiVariableDebtToken = AnteiVariableDebtToken(anteiVariableDebtAddress);
    emit VariableDebtTokenSet(anteiVariableDebtAddress);
  }

  function getVariableDebtToken() external view override returns (address) {
    return address(_anteiVariableDebtToken);
  }

  function setTreasury(address newTreasury) external override onlyLendingPoolAdmin {
    address previousTreasury = _anteiTreasury;
    _anteiTreasury = newTreasury;
    emit TreasuryUpdated(previousTreasury, newTreasury);
  }

  function getTreasury() external view override returns (address) {
    return _anteiTreasury;
  }
}
