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

contract AutoCoin is ERC20 {

    using SafeMath for uint256;

    address public              owner;
    address private             subowner;

    uint256 private             summarySupply;
    uint256 public              weiPerMinToken;

    string  public              name = "Auto Token";
    string  public              symbol = "ATK";
    uint8   public              decimals = 2;

    bool    public              contractEnable = true;
    bool    public              transferEnable = false;


    mapping(address => uint8)                        private   group;
    mapping(address => uint256)                      private   accounts;
    mapping(address => mapping (address => uint256)) private   allowed;

    event EvGroupChanged(address _address, uint8 _oldgroup, uint8 _newgroup);
    event EvTokenAdd(uint256 _value, uint256 _lastSupply);
    event EvTokenRm(uint256 _delta, uint256 _value, uint256 _lastSupply);
    event EvLoginfo(string _functionName, string _text);
    event EvMigration(address _address, uint256 _balance, uint256 _secret);

    struct groupPolicy {
        uint8 _default;
        uint8 _backend;
        uint8 _migration;
        uint8 _admin;
        uint8 _subowner;
        uint8 _owner;
    }

    groupPolicy private currentState = groupPolicy(0, 3, 9, 4, 2, 9);

    function AutoCoin(string _name, string _symbol, uint8 _decimals, uint256 _weiPerMinToken, uint256 _startTokens) public {
        owner = msg.sender;
        group[msg.sender] = 9;

        if (_weiPerMinToken != 0)
            weiPerMinToken = _weiPerMinToken;

        accounts[owner]  = _startTokens;
        summarySupply    = _startTokens;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    modifier minGroup(int _require) {
        require(group[msg.sender] >= _require);
        _;
    }

    modifier onlyPayloadSize(uint size) {
        assert(msg.data.length >= size + 4);
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


    function settingsSetWeiPerMinToken(uint256 _weiPerMinToken) minGroup(currentState._admin) external {
        if (_weiPerMinToken > 0) {
            weiPerMinToken = _weiPerMinToken;

            EvLoginfo("[weiPerMinToken]", "changed");
        }
    }

    function serviceIncreaseBalance(address _who, uint256 _value) minGroup(currentState._backend) external returns(bool) {
        accounts[_who] = accounts[_who].safeAdd(_value);
        summarySupply = summarySupply.safeAdd(_value);

        EvTokenAdd(_value, summarySupply);
        return true;
    }

    function serviceDecreaseBalance(address _who, uint256 _value) minGroup(currentState._backend) external returns(bool) {
        accounts[_who] = accounts[_who].safeSub(_value);
        summarySupply = summarySupply.safeSub(_value);

        EvTokenRm(accounts[_who], _value, summarySupply);
        return true;
    }

    function serviceTokensBurn(address _address) external minGroup(currentState._backend) returns(uint256 balance) {
        accounts[_address] = 0;
        return accounts[_address];
    }

    function serviceChangeOwner(address _newowner) minGroup(currentState._subowner) external returns(address) {
        address temp;
        uint256 value;

        if (msg.sender == owner) {
            subowner = _newowner;
            group[msg.sender] = currentState._subowner;
            group[_newowner] = currentState._subowner;

            EvGroupChanged(_newowner, currentState._owner, currentState._subowner);
        }

        if (msg.sender == subowner) {
            temp = owner;
            value = accounts[owner];

            accounts[owner] = accounts[owner].safeSub(value);
            accounts[subowner] = accounts[subowner].safeAdd(value);

            owner = subowner;

            delete group[temp];
            group[subowner] = currentState._owner;

            subowner = 0x00;

            EvGroupChanged(_newowner, currentState._subowner, currentState._owner);
        }

        return subowner;
    }

    function userTransfer(address _to, uint256 _value) onlyPayloadSize(64) minGroup(currentState._default) external returns (bool success) {
        if (accounts[msg.sender] >= _value && (transferEnable || group[msg.sender] >= currentState._backend)) {
            accounts[msg.sender] = accounts[msg.sender].safeSub(_value);
            accounts[_to] = accounts[_to].safeAdd(_value);
            Transfer(msg.sender, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function userTransferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(64) minGroup(currentState._default) external returns (bool success) {
        if ((accounts[_from] >= _value) && (allowed[_from][msg.sender] >= _value) && (transferEnable || group[msg.sender] >= currentState._backend)) {
            accounts[_from] = accounts[_from].safeSub(_value);
            allowed[_from][msg.sender] = allowed[_from][msg.sender].safeSub(_value);
            accounts[_to] = accounts[_to].safeAdd(_value);
            Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function userApprove(address _spender, uint256 _old, uint256 _new) onlyPayloadSize(64) minGroup(currentState._default) external returns (bool success) {
        if (_old == allowed[msg.sender][_spender]) {
            allowed[msg.sender][_spender] = _new;
            Approval(msg.sender, _spender, _new);
            return true;
        } else {
            return false;
        }
    }

    function allowance(address _owner, address _spender) external constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function balanceOf(address _owner) external constant returns (uint256 balance) {
        if (_owner == 0x00)
            return accounts[msg.sender];
        return accounts[_owner];
    }

    function totalSupply() external constant returns (uint256 _totalSupply) {
        _totalSupply = summarySupply;
    }

    function destroy() minGroup(currentState._owner) external {
        selfdestruct(owner);
    }

    function settingsSwitchState() external minGroup(currentState._owner) returns (bool state) {

        if(contractEnable) {
            currentState._default = 9;
            currentState._migration = 0;
            contractEnable = false;
        } else {
            currentState._default = 0;
            currentState._migration = 9;
            contractEnable = true;
        }

        return contractEnable;
    }

    function settingsSwitchTransferAccess() external minGroup(currentState._backend) returns (bool access) {
        transferEnable = !transferEnable;
        return transferEnable;
    }

    function userMigration(uint256 _secrect) external minGroup(currentState._migration) returns (bool successful) {

        uint256 balance = accounts[msg.sender];
        if (balance > 0) {
            accounts[msg.sender] = accounts[msg.sender].safeSub(balance);
            accounts[owner] = accounts[owner].safeAdd(balance);
            EvMigration(msg.sender, balance, _secrect);
            return true;
        }
        else
            return false;
    }
}

contract Node is GroupManaged {

    using SafeMath for uint256;

    AutoCoin    public  parent;

    mapping(address => mapping(uint256 => accountParams))   private   accounts;
    mapping(address => uint256)                             private   purchaseCount;

    struct accountParams {
        uint256 _date;
        uint256 _tokens;
    }

    uint256                             public  startTime;
    uint256                             public  durationInSeconds;
    uint8                               public  sale;

    bool                                private _alreadyEnd = false;
    uint256                             private _endDate;

    event EvTokenBuy(address _to, uint256 _value);

    function Node(address _conowner, uint256 _startTime, uint256 _durationInSeconds, uint8 _sale) GroupManaged() public {
        parent = AutoCoin(_conowner);

        require(parent.owner() == msg.sender);
        sale = _sale;
        startTime = _startTime;
        durationInSeconds = _durationInSeconds;
    }

    modifier onlyOwner(){
        require(msg.sender == parent.owner());
        _;
    }

    function infoIsActive() public constant returns (bool) {
        return (infoTime() >= startTime && infoCurrentSeconds() <= durationInSeconds) && !_alreadyEnd;
    }

    function infoCountTokens(uint256 weiCount) public constant returns (uint256) {
        return weiCount.safeDiv(this.infoTokenCostValue());
    }

    function infoTime() public constant returns (uint256) {
        return block.timestamp;
    }

    function infoTokenCostValue() public constant returns (uint256) {
        uint256 value = parent.weiPerMinToken();
        uint256 procent = 100;
        value = value.safeMul(procent.safeSub(sale));
        value = value.safeDiv(100);
        return value;
    }

    function infoCurrentSeconds() public constant returns (uint256) {
        return infoSecondsFor(infoTime());
    }

    function infoSecondsFor(uint256 timestamp) public constant returns (uint256) {
        return timestamp < startTime
        ? 0
        : timestamp.safeSub(startTime);
    }

    function infoActiveOnDate(uint256 timestamp) external minGroup(currentState._backend) constant returns (bool){
        return timestamp >= startTime && infoSecondsFor(timestamp) <= durationInSeconds && !_alreadyEnd;
    }

    function infoAccountTokens(address _address,uint256 index) external minGroup(currentState._backend) constant returns(uint256 date, uint256 tokens) {
        require(index < purchaseCount[_address]);
        accountParams storage currentAccount = accounts[_address][index];
        return (currentAccount._date, currentAccount._tokens);
    }

    function infoAccountPurchaseCount(address _address) external minGroup(currentState._backend) constant returns(uint256 count) {
        return purchaseCount[_address];
    }

    function infoTokensLeft() public constant returns(uint256 balance) {
        return parent.balanceOf(this);
    }

    function serviceDestroy() external onlyOwner() {
        uint256 balance = parent.balanceOf(this);
        require(parent.userTransfer(parent.owner(), balance));

        selfdestruct(parent.owner());
    }
    //обновление времени, с которого нода активна
    function servicesUpdateStartTime(uint256 newTime) external minGroup(currentState._backend){
        startTime = newTime;
    }
    //Проверка. что нода закрыта внепланово
    function serviceIsFinishedBeforePlanEnd() external minGroup(currentState._backend) constant returns(bool) {
        return _alreadyEnd;
    }
    //Дата внепланового закрытия ноды
    function serviceGetUnplanedEndDate() external minGroup(currentState._backend) constant returns(uint256) {
        return _endDate;
    }
    //Ручное внеплановое закрытие ноды, время на следующей ноде нужно изменить вручную
    function serviceForceNodeEnd() external minGroup(currentState._backend) {
        _alreadyEnd = true;
        _endDate = this.infoTime();
    }
    //Перевод остатка токенов, работает только в случае закрытия ноды(по/вне плана)
    function serviceEndTransferBalance(address _to) external minGroup(currentState._backend) returns(bool){
        if(this.infoIsActive()){
            return false;
        }

        uint256 balance = this.infoTokensLeft();

        if(balance == 0){
            return true;
        }

        return parent.userTransfer(_to, balance);
    }

    function transfer(address _to, uint256 _value, bool _rememberPurchase) external minGroup(currentState._backend) returns(bool){
        assert(this.infoIsActive());

        if(this.infoTokensLeft() < _value){
            return false;
        }
        if(parent.userTransfer(_to, _value)){
            if(_rememberPurchase)
            {
                accounts[_to][purchaseCount[_to]] = accountParams(infoTime(),_value);
                purchaseCount[_to] = purchaseCount[_to].safeAdd(1);
            }
            if(this.infoTokensLeft() == 0){
                _alreadyEnd = true;
                _endDate = this.infoTime();
            }
            EvTokenBuy(_to,_value);
            return true;
        } else {
            return false;
        }
    }
}

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

