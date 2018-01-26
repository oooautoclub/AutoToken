pragma solidity ^0.4.15;

import "./SafeMath.sol";
import "./AutoCoin.sol";
import "./GroupManaged.sol";

contract InfinityNode is GroupManaged {

    using SafeMath for uint256;

    AutoCoin    public  parent;

    function InfinityNode(address _conowner) GroupManaged() public {
        parent = AutoCoin(_conowner);

        require(parent.owner() == msg.sender);
    }

    modifier onlyOwner(){
        require(msg.sender == parent.owner());
        _;
    }

    function infoTokensLeft() public constant returns(uint256 balance) {
        return parent.balanceOf(this);
    }

    function serviceDestroy() external onlyOwner() {
        uint256 balance = parent.balanceOf(this);
        require(parent.userTransfer(parent.owner(), balance));

        selfdestruct(parent.owner());
    }

    function transfer(address _to, uint256 _value) external minGroup(currentState._backend) returns(bool){
        if(this.infoTokensLeft() < _value){
            return false;
        }
        return parent.userTransfer(_to, _value);
    }
}

