// Definition of RAY unit
function first_term(uint256 x, uint256 y) returns uint256 { return x; }

ghost mapping(uint256 => mapping(uint256 => uint256)) rayMulSummariztionValues;
function rayMulSummariztion(uint256 x, uint256 y) returns uint256
{
	if ((x == 0) || (y == 0))
	{
		return 0;
	}
	if (x == ray())
	{
		return y;
	}
	if (y == ray())
	{
		return x;
	}
	
	if (y > x)
	{
		if (y > ray())
		{
			require rayMulSummariztionValues[y][x] >= x;
		}
		if (x > ray())
		{
			require rayMulSummariztionValues[y][x] >= y;
		}
		return rayMulSummariztionValues[y][x];
	}
	else{
		if (x > ray())
		{
			require rayMulSummariztionValues[x][y] >= y;
		}
		if (y > ray())
		{
			require rayMulSummariztionValues[x][y] >= x;
		}
		return rayMulSummariztionValues[x][y];
	}
}