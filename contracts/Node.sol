pragma solidity ^0.4.15;

import "./SafeMath.sol";
import "./AutoCoin.sol";
import "./GroupManaged.sol";

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