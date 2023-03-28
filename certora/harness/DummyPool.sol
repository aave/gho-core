contract DummyPool {
    function getReserveNormalizedVariableDebt(address asset) external view returns (uint256) {
        return _getReserveNormalizedVariableDebtWithBlockTimestamp(asset, block.timestamp);
    }

    function _getReserveNormalizedVariableDebtWithBlockTimestamp(address asset, uint256 blockTs) internal view returns (uint256) {
        return 0; // will be replaced by a sammury in the spec file
    }
}