contract DummyERC20WithTimedBalanceOf {
  function balanceOf(address user) public view virtual returns (uint256) {
    return _balanceOfWithBlockTimestamp(user, block.timestamp);
  }

  function _balanceOfWithBlockTimestamp(
    address user,
    uint256 blockTs
  ) internal view returns (uint256) {
    return 0; // STUB! Should be summarized
  }
}
