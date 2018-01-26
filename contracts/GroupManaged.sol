pragma solidity ^0.4.15;

contract GroupManaged {

    mapping(address => uint8)           private   group;

    struct groupPolicy {
        uint8 _backend;
        uint8 _admin;
    }

    groupPolicy public currentState = groupPolicy(3,4);

    event EvGroupChanged(address _address, uint8 _oldgroup, uint8 _newgroup);

    function GroupManaged() public {
        group[msg.sender] = currentState._admin;
    }

    modifier minGroup(int _require) {
        require(group[msg.sender] >= _require || msg.sender == address(this));
        _;
    }

    function serviceGroupChange(address _address, uint8 _group) minGroup(currentState._admin) external returns(uint8) {
        uint8 old = group[_address];
        if(old <= currentState._admin) {
            group[_address] = _group;
            EvGroupChanged(_address, old, _group);
        }
        return group[_address];
    }

    function serviceGroupGet(address _check) minGroup(currentState._backend) external constant returns(uint8 _group) {
        return group[_check];
    }
}
