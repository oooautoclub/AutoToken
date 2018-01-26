pragma solidity ^0.4.15;

import "./SafeMath.sol";
import "./Node.sol";
import "./GroupManaged.sol";
import "./InfinityNode.sol";

contract EtherReceiver is GroupManaged {

    using SafeMath for uint256;

    Node[]      public crounsaleNodes;
    InfinityNode        public bonusNode;

    AutoCoin    public  parent;

    uint256     private breakBetweenNodeSeconds;

    mapping(address => nodeParams) private _nodeIndex;

    struct nodeParams {
        bool _isNode;
        uint256 _index;
    }
    //Важен порядок адресов нод, время старта по возрастанию
    function EtherReceiver(address _conowner, address[] crounsaleNodesAddresses, address bonusNodeAddress, uint256 _breakBetweenNodeSeconds) GroupManaged() public {
        assert(crounsaleNodesAddresses.length > 0);
        crounsaleNodes = new Node[](crounsaleNodesAddresses.length);
        for(uint256 i = 0; i < crounsaleNodesAddresses.length;i++) {
            crounsaleNodes[i] = Node(crounsaleNodesAddresses[i]);
            _nodeIndex[crounsaleNodesAddresses[i]] = nodeParams(true,i);
        }

        bonusNode = InfinityNode(bonusNodeAddress);
        parent = AutoCoin(_conowner);
        breakBetweenNodeSeconds = _breakBetweenNodeSeconds;
    }

    modifier onlyOwner(){
        require(msg.sender == parent.owner());
        _;
    }

    function getBreakBetweenNode() public minGroup(currentState._backend) constant returns(uint256 index){

        return breakBetweenNodeSeconds;
    }
    //return index + 1
    function getCurrentNode() public minGroup(currentState._backend) constant returns(uint256 index){
        uint256 result = 0;
        for(uint256 i = 0; i < crounsaleNodes.length; i++) {
            if(crounsaleNodes[i].infoIsActive()) {
                if(result == 0){
                    result = i.safeAdd(1);
                } else {
                    break;
                }
            }
        }
        return result;
    }
    //return index + 1
    function getNodeByDate(uint256 date) external minGroup(currentState._backend) constant returns(uint256 index){
        for(uint256 i = 0; i < crounsaleNodes.length; i++) {
            if(crounsaleNodes[i].infoActiveOnDate(date)) {
                return i + 1;
            }
        }
        return 0;
    }

    //Warning: not included removed or replaced nodes
    function totalBought() external minGroup(currentState._backend) constant returns (uint256) {
        uint256 totalSupply = parent.totalSupply();
        uint256 totalLeft;
        for(uint256 i = 0; i < crounsaleNodes.length; i++) {
            totalLeft = totalLeft.safeAdd(crounsaleNodes[i].infoTokensLeft());
        }
        totalLeft = totalLeft.safeAdd(bonusNode.infoTokensLeft());
        totalLeft = totalLeft.safeAdd(parent.balanceOf(parent.owner()));
        return totalSupply.safeSub(totalLeft);
    }

    function addNode(address newNodeAddress) external minGroup(currentState._backend) returns(uint256 index){
        require(!_nodeIndex[newNodeAddress]._isNode);
        crounsaleNodes.push(Node(newNodeAddress));
        _nodeIndex[newNodeAddress] = nodeParams(true,crounsaleNodes.length.safeSub(1));
        return _nodeIndex[newNodeAddress]._index;
    }

    function removeNode(address removeNodeAddress) external minGroup(currentState._backend) returns(uint256 index){
        require(_nodeIndex[removeNodeAddress]._isNode);
        assert(crounsaleNodes.length > 0);
        index = 1;
        if(crounsaleNodes.length > 1) {
            index = _nodeIndex[removeNodeAddress]._index;
            crounsaleNodes[index] = crounsaleNodes[crounsaleNodes.length.safeSub(1)];
        }
        delete _nodeIndex[removeNodeAddress];
        crounsaleNodes.length = crounsaleNodes.length.safeSub(1);
    }

    function replaceNode(address oldNodeAddress, address newNodeAddress) external minGroup(currentState._backend) returns(uint256 index){
        require(_nodeIndex[oldNodeAddress]._isNode);
        require(!_nodeIndex[newNodeAddress]._isNode);
        require(oldNodeAddress != newNodeAddress);
        assert(crounsaleNodes.length > 1);
        crounsaleNodes[_nodeIndex[oldNodeAddress]._index] = Node(newNodeAddress);
        _nodeIndex[newNodeAddress] = _nodeIndex[oldNodeAddress];
        delete _nodeIndex[oldNodeAddress];
        return _nodeIndex[newNodeAddress]._index;
    }

    function replaceBonusNode(address newNodeAddress) external minGroup(currentState._backend){
        require(newNodeAddress != address(bonusNode));
        bonusNode = InfinityNode(newNodeAddress);
    }

    function crounsaleNodeCount() external minGroup(currentState._backend) constant returns(uint256 count){
        return crounsaleNodes.length;
    }

    function getNodeBalance(address _address,uint256 nodeIndex,uint256 arrayIndex) external minGroup(currentState._backend) constant returns(uint256 date,uint256 tokens){
        assert(nodeIndex >= 0 && nodeIndex < crounsaleNodes.length);
        uint256 purchaseCount = crounsaleNodes[nodeIndex].infoAccountPurchaseCount(_address);
        assert(purchaseCount > arrayIndex);
        return crounsaleNodes[nodeIndex].infoAccountTokens(_address,arrayIndex);
    }

    function getNodeAccountPurchaseCount(address _address,uint256 nodeIndex) external minGroup(currentState._backend) constant returns(uint256 count){
        uint256 purchaseCount = crounsaleNodes[nodeIndex].infoAccountPurchaseCount(_address);
        return purchaseCount;
    }

    function transfer(address to, uint256 value) external minGroup(currentState._backend){
        uint256 nodeIndex = this.getCurrentNode();
        assert(nodeIndex > 0);
        require(crounsaleNodes[nodeIndex.safeSub(1)].transfer( to, value, false));
    }

    function transferBonus(address to, uint256 value) external minGroup(currentState._backend){
        require(bonusNode.transfer( to, value));
    }

    function serviceGetWei() external minGroup(currentState._admin) returns(bool success) {
        uint256 contractBalance = this.balance;
        parent.owner().transfer(contractBalance);

        return true;
    }

    function serviceDestroy() external onlyOwner() {
        selfdestruct(parent.owner());
    }

    function() external payable {
        uint256 nodeIndex = this.getCurrentNode();
        assert(nodeIndex > 0);
        nodeIndex = nodeIndex.safeSub(1);
        Node node = crounsaleNodes[nodeIndex];
        uint256 tokenCount = node.infoCountTokens(msg.value);
        if(tokenCount != 0 && node.transfer(msg.sender,tokenCount, true)){
            if(!node.infoIsActive()){
                if(nodeIndex < crounsaleNodes.length.safeSub(1)){
                    Node nextNode = crounsaleNodes[nodeIndex.safeAdd(1)];
                    node.serviceEndTransferBalance(address(nextNode));
                    if(node.serviceIsFinishedBeforePlanEnd()){
                        uint256 newTime = node.serviceGetUnplanedEndDate();
                        nextNode.servicesUpdateStartTime(newTime.safeAdd(breakBetweenNodeSeconds));
                    }
                }
            } else {
                if(nodeIndex > 0){
                    Node prevNode = crounsaleNodes[nodeIndex.safeSub(1)];
                    if(prevNode.infoTokensLeft() > 0){
                        prevNode.serviceEndTransferBalance(address(node));
                    }
                }
            }
        }
    }
}