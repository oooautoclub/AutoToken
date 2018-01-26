pragma solidity ^0.4.15;

contract ERC20 {
    function totalSupply() external constant returns (uint256 _totalSupply);
    function balanceOf(address _owner) external constant returns (uint256 balance);
    function userTransfer(address _to, uint256 _value) external returns (bool success);
    function userTransferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function userApprove(address _spender, uint256 _old, uint256 _new) external returns (bool success);
    function allowance(address _owner, address _spender) external constant returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function ERC20() internal {
    }
}