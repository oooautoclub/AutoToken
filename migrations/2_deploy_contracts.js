var EtherReceiver = artifacts.require("./EtherReceiver.sol");
var Node = artifacts.require("./NODE.sol");
var AutoCoin = artifacts.require('./AutoCoin.sol')
var InfinityNode = artifacts.require('./InfinityNode.sol')

function time(){
    return parseInt(new Date().getTime()/1000)
}

module.exports =  deployer => {
    deployer.deploy(AutoCoin, "Autocoin","ATC",2,1000000, 100000000000).then(() => {
        deployer.link(AutoCoin, Node)
        deployer.deploy(Node, AutoCoin.address, time(), 120, 70).then(() => {
            deployer.link(Node, EtherReceiver)
            deployer.deploy(InfinityNode, AutoCoin.address).then(() => {
                deployer.link(InfinityNode, EtherReceiver)
                deployer.deploy(EtherReceiver, AutoCoin.address, [Node.address], InfinityNode.address, 120)
            })
        })
    })
}
