// The (unverified) summary for OpenZeppelin's `Math.mulDiv`.
// Use with care!
methods
{
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator) internal returns (uint256) => mulDivSummary(x, y, denominator);
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256) => mulDivSummaryRounding(x, y, denominator, rounding);
}

function mulDivSummary(uint256 x, uint256 y, uint256 denominator) returns uint256
{
    require denominator > 0;
    return require_uint256((x*y)/denominator);
}

function mulDivSummaryRounding(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256
{
    if (rounding == Math.Rounding.Up) {
        require denominator > 0;
        return require_uint256((x * y + denominator - 1) / denominator);
    } else {
        return mulDivSummary(x, y, denominator);
    }
}
