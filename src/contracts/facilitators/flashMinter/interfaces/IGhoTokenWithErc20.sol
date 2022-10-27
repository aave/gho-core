pragma solidity ^0.8.0;

import '../../../gho/interfaces/IGhoToken.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IGhoTokenWithErc20 is IERC20, IGhoToken {}
