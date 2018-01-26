pragma solidity ^0.4.15;

library SafeMath {
    uint256 constant private    MAX_UINT256     = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    function safeAdd (uint256 x, uint256 y) internal pure returns (uint256 z) {
        assert (x <= MAX_UINT256 - y);
        return x + y;
    }

    function safeSub (uint256 x, uint256 y) internal pure returns (uint256 z) {
        assert (x >= y);
        return x - y;
    }

    function safeMul (uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y;
        assert(x == 0 || z / x == y);
    }

    function safeDiv (uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x / y;
        return z;
    }
}