// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Gsm} from '../Gsm.sol';
import {GsmToken} from '../token/GsmToken.sol';

/**
 * @title GsmFactory
 * @author Aave
 * @notice Helper contract for deploying GSMs and associated contracts
 */
contract GsmFactory is Ownable {
  /**
   * @notice Deploys a new GSM
   * @param salt CREATE2 salt to be used for deployment
   * @param ghoToken The address of the GHO token contract
   * @param underlyingAsset The address of the collateral asset
   */
  function deployGsm(
    bytes32 salt,
    address ghoToken,
    address underlyingAsset
  ) external onlyOwner returns (address) {
    bytes memory args = abi.encodePacked(
      type(Gsm).creationCode,
      abi.encode(ghoToken, underlyingAsset)
    );
    address expectedAddress = _precomputeAddress(salt, args);
    require(!_isContract(expectedAddress), 'CONTRACT_ALREADY_DEPLOYED');
    address deployedContract = address(new Gsm{salt: salt}(ghoToken, underlyingAsset));
    require(deployedContract == expectedAddress, 'UNEXPECTED_GSM_DEPLOYMENT_ADDRESS');
    return expectedAddress;
  }

  /**
   * @notice Deploys a new GsmToken
   * @param salt CREATE2 salt to be used for deployment
   * @param admin Address granted DEFAULT_ADMIN_ROLE
   * @param name Token name
   * @param symbol Token symbol
   * @param decimals Token decimals
   * @param underlyingAsset Underlying asset that will back a GsmToken
   */
  function deployGsmToken(
    bytes32 salt,
    address admin,
    string memory name,
    string memory symbol,
    uint8 decimals,
    address underlyingAsset
  ) external onlyOwner returns (address) {
    bytes memory args = abi.encodePacked(
      type(GsmToken).creationCode,
      abi.encode(admin, name, symbol, decimals, underlyingAsset)
    );
    address expectedAddress = _precomputeAddress(salt, args);
    require(!_isContract(expectedAddress), 'CONTRACT_ALREADY_DEPLOYED');
    address deployedContract = address(
      new GsmToken{salt: salt}(admin, name, symbol, decimals, underlyingAsset)
    );
    require(deployedContract == expectedAddress, 'UNEXPECTED_GSM_TOKEN_DEPLOYMENT_ADDRESS');
    return expectedAddress;
  }

  /**
   * @notice Returns whether the address is a contract by checking it has deployed bytecode
   * @param account Address to check for bytecode
   */
  function _isContract(address account) internal view returns (bool) {
    return account.code.length > 0;
  }

  /**
   * @notice Returns the precomputed CREATE2 deployment address
   * @param salt CREATE2 salt
   * @param bytecode ABI-encoded creation code and args to precompute an address
   */
  function _precomputeAddress(bytes32 salt, bytes memory bytecode) internal view returns (address) {
    return
      address(
        uint160(
          uint256(
            keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)))
          )
        )
      );
  }
}
