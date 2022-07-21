// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
  uint256 constant MAX_UINT256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

  /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

  bytes32 constant TRANSFER_EVENT_SIG =
    0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
  event Transfer(address indexed from, address indexed to, uint256 amount);

  event Approval(address indexed owner, address indexed spender, uint256 amount);

  /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

  string public name;

  string public symbol;

  uint8 public immutable decimals;

  /*///////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

  uint256 public totalSupply;

  mapping(address => uint256) public balanceOf;

  mapping(address => mapping(address => uint256)) public allowance;

  /*///////////////////////////////////////////////////////////////
                             EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

  bytes32 public constant PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  uint256 internal immutable INITIAL_CHAIN_ID;

  bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

  mapping(address => uint256) public nonces;

  /*///////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals
  ) {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;

    INITIAL_CHAIN_ID = block.chainid;
    INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
  }

  /*///////////////////////////////////////////////////////////////
                              ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

  function approve(address spender, uint256 amount) public virtual returns (bool) {
    assembly {
      mstore(0, caller())
      mstore(32, allowance.slot)
      mstore(32, keccak256(0, 64))
      mstore(0, spender)

      sstore(keccak256(0, 64), amount)
    }

    emit Approval(msg.sender, spender, amount);

    return true;
  }

  function transfer(address to, uint256 amount) public virtual returns (bool) {
    assembly {
      mstore(0, caller())
      mstore(32, balanceOf.slot)

      let senderSlot := keccak256(0, 64)
      let beforeSenderBalance := sload(senderSlot)
      let afterSenderBalance := sub(beforeSenderBalance, amount)

      // True if there is an underflow.
      if iszero(gt(beforeSenderBalance, afterSenderBalance)) {
        revert(0, 0)
      }

      sstore(senderSlot, afterSenderBalance)

      // No need to mstore the slot again.
      mstore(0, to)

      let receiverSlot := keccak256(0, 64)
      sstore(receiverSlot, add(sload(receiverSlot), amount))

      // Emit the Transfer event.
      mstore(0, amount)
      log3(0, 32, TRANSFER_EVENT_SIG, caller(), to)
    }
    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual returns (bool) {
    assembly {
      mstore(0, from)
      mstore(32, allowance.slot)
      mstore(32, keccak256(0, 64))
      mstore(0, caller())

      let allowanceSlot := keccak256(0, 64)

      let allowed := sload(allowanceSlot)

      //Not max allowance
      if iszero(eq(allowed, MAX_UINT256)) {
        let allowanceAfter := sub(allowed, amount)

        // True if there is an underflow.
        if iszero(gt(allowed, allowanceAfter)) {
          revert(0, 0)
        }

        sstore(allowanceSlot, allowanceAfter)
      }

      // Update from balance.
      mstore(0, from)
      mstore(32, balanceOf.slot)

      let fromBalanceSlot := keccak256(0, 64)
      let fromBalanceBefore := sload(fromBalanceSlot)
      let fromBalanceAfter := sub(fromBalanceBefore, amount)

      // True if there is an underflow.
      if iszero(gt(fromBalanceBefore, fromBalanceAfter)) {
        revert(0, 0)
      }
      sstore(fromBalanceSlot, fromBalanceAfter)

      // Update to balance.
      mstore(0, to)
      let toBalanceSlot := keccak256(0, 64)
      let toBalanceBefore := sload(toBalanceSlot)

      sstore(toBalanceSlot, add(toBalanceBefore, amount))

      mstore(0, amount)
      log3(0, 32, TRANSFER_EVENT_SIG, from, to)
    }
    return true;
  }

  /*///////////////////////////////////////////////////////////////
                              EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual {
    require(deadline >= block.timestamp, 'PERMIT_DEADLINE_EXPIRED');

    // Unchecked because the only math done is incrementing
    // the owner's nonce which cannot realistically overflow.
    unchecked {
      bytes32 digest = keccak256(
        abi.encodePacked(
          '\x19\x01',
          DOMAIN_SEPARATOR(),
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
        )
      );

      address recoveredAddress = ecrecover(digest, v, r, s);

      require(recoveredAddress != address(0) && recoveredAddress == owner, 'INVALID_SIGNER');

      allowance[recoveredAddress][spender] = value;
    }

    emit Approval(owner, spender, value);
  }

  function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
    return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
  }

  function computeDomainSeparator() internal view virtual returns (bytes32) {
    return
      keccak256(
        abi.encode(
          keccak256(
            'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
          ),
          keccak256(bytes(name)),
          keccak256('1'),
          block.chainid,
          address(this)
        )
      );
  }

  /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

  function _mint(address to, uint256 amount) internal virtual {
    totalSupply += amount;

    // Cannot overflow because the sum of all user
    // balances can't exceed the max uint256 value.
    unchecked {
      balanceOf[to] += amount;
    }

    emit Transfer(address(0), to, amount);
  }

  function _burn(address from, uint256 amount) internal virtual {
    balanceOf[from] -= amount;

    // Cannot underflow because a user's balance
    // will never be larger than the total supply.
    unchecked {
      totalSupply -= amount;
    }

    emit Transfer(from, address(0), amount);
  }
}
