```diff
diff --git a/src/contracts/gho/ERC20.sol b/src/contracts/gho/UpgradeableERC20.sol
index d0cad6b..aa25fcb 100644
--- a/src/contracts/gho/ERC20.sol
+++ b/src/contracts/gho/UpgradeableERC20.sol
@@ -4,12 +4,14 @@ pragma solidity ^0.8.0;
 import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

 /**
- * @title ERC20
- * @notice Gas Efficient ERC20 + EIP-2612 implementation
- * @dev Modified version of Solmate ERC20 (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol),
- * implementing the basic IERC20
+ * @title UpgradeableERC20
+ * @author Aave Labs
+ * @notice Upgradeable version of Solmate ERC20
+ * @dev Contract adaptations:
+ * - Removal of domain separator optimization
+ * - Move of name and symbol definition to initialization stage
  */
-abstract contract ERC20 is IERC20 {
+abstract contract UpgradeableERC20 is IERC20 {
   /*///////////////////////////////////////////////////////////////
                              METADATA STORAGE
     //////////////////////////////////////////////////////////////*/
@@ -37,23 +39,23 @@ abstract contract ERC20 is IERC20 {
   bytes32 public constant PERMIT_TYPEHASH =
     keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

-  uint256 internal immutable INITIAL_CHAIN_ID;
-
-  bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
-
   mapping(address => uint256) public nonces;

   /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
     //////////////////////////////////////////////////////////////*/

-  constructor(string memory _name, string memory _symbol, uint8 _decimals) {
+  constructor(uint8 _decimals) {
+    decimals = _decimals;
+  }
+
+  /*///////////////////////////////////////////////////////////////
+                               INITIALIZER
+    //////////////////////////////////////////////////////////////*/
+
+  function _ERC20_init(string memory _name, string memory _symbol) internal {
     name = _name;
     symbol = _symbol;
-    decimals = _decimals;
-
-    INITIAL_CHAIN_ID = block.chainid;
-    INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
   }

   /*///////////////////////////////////////////////////////////////
@@ -137,7 +139,7 @@ abstract contract ERC20 is IERC20 {
   }

   function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
-    return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
+    return computeDomainSeparator();
   }

   function computeDomainSeparator() internal view virtual returns (bytes32) {
```
