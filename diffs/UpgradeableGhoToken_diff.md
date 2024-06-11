```diff
diff --git a/src/contracts/gho/GhoToken.sol b/src/contracts/gho/UpgradeableGhoToken.sol
index 854e10f..402788c 100644
--- a/src/contracts/gho/GhoToken.sol
+++ b/src/contracts/gho/UpgradeableGhoToken.sol
@@ -3,14 +3,15 @@ pragma solidity ^0.8.0;

 import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
 import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
-import {ERC20} from './ERC20.sol';
+import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';
+import {UpgradeableERC20} from './UpgradeableERC20.sol';
 import {IGhoToken} from './interfaces/IGhoToken.sol';

 /**
- * @title GHO Token
- * @author Aave
+ * @title Upgradeable GHO Token
+ * @author Aave Labs
  */
-contract GhoToken is ERC20, AccessControl, IGhoToken {
+contract UpgradeableGhoToken is Initializable, UpgradeableERC20, AccessControl, IGhoToken {
   using EnumerableSet for EnumerableSet.AddressSet;

   mapping(address => Facilitator) internal _facilitators;
@@ -24,10 +25,19 @@ contract GhoToken is ERC20, AccessControl, IGhoToken {

   /**
    * @dev Constructor
+   */
+  constructor() UpgradeableERC20(18) {
+    // Intentionally left bank
+  }
+
+  /**
+   * @dev Initializer
    * @param admin This is the initial holder of the default admin role
    */
-  constructor(address admin) ERC20('Gho Token', 'GHO', 18) {
-    _setupRole(DEFAULT_ADMIN_ROLE, admin);
+  function initialize(address admin) public virtual initializer {
+    _ERC20_init('Gho Token', 'GHO');
+
+    _grantRole(DEFAULT_ADMIN_ROLE, admin);
   }

   /// @inheritdoc IGhoToken
```
