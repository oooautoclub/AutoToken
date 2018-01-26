var EtherReceiver = artifacts.require('./EtherReceiver.sol')
var Node = artifacts.require('./Node.sol')
var AutoCoin = artifacts.require('./AutoCoin.sol')
var InfinityNode = artifacts.require('./InfinityNode.sol')
var BigNumber = require('bignumber.js')
const web3 = AutoCoin.web3

let MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

function validateValues(test, ideal) {
    var result = 0
    var temp = 0

    if (ideal.length === test.length) {
        ideal.forEach(function(element) {
            if (element == test[temp]) {
                result++
            }
            temp++
        }, this)
    }
    return result
}

function time(date) {
    return parseInt(date.getTime() / 1000)
}

contract('AutoCoin', accounts => {
    let name = 'Autocoin'
    let symbol = 'ATC'
    let decimals = 2
    let weiPerToken = 1000000000
    let totalSupply = 1000000000000

    let currentNode = 1
    let nodeCount = 5
    let nodeSeconds = 10
    let receiverBreakSeconds = 1
    let date = new Date()
    let tokenInstance
    let nodeInstances = []
    let bonusInstance
    let receiverInstance

    it('(Init...) Token', async () => {
        tokenInstance = await AutoCoin.new(name, symbol, decimals, weiPerToken, totalSupply, {from: accounts[0]})
        assert.ok(tokenInstance)

        let tmp = []

        tmp.push((await tokenInstance.balanceOf(accounts[0])).valueOf())
        tmp.push((await tokenInstance.decimals()).valueOf())
        tmp.push((await tokenInstance.weiPerMinToken()).valueOf())
        tmp.push((await tokenInstance.name()).valueOf())
        tmp.push((await tokenInstance.symbol()).valueOf())
        tmp.push((await tokenInstance.owner()).valueOf())

        let ideal = [totalSupply, decimals, weiPerToken, name, symbol, accounts[0]]
        let result = validateValues(tmp, ideal)

        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })

    it('(Init...) Nodes & bonus node', async () => {
        let tmp = []
        let ideal = []
        let value = totalSupply / 10

        bonusInstance = await InfinityNode.new(
            tokenInstance.address,
            {
                from: accounts[0],
            },
        )

        assert.ok(bonusInstance)
        for (let i = 0; i < nodeCount; i++) {
            let node = await Node.new(
                tokenInstance.address,
                time(date) + (i - currentNode) * (nodeSeconds + receiverBreakSeconds),
                nodeSeconds,
                10,
                {
                    from: accounts[0],
                },
            )
            assert.ok(node)
            nodeInstances.push(node)
        }
        let commonArray = nodeInstances.slice()
        commonArray.push(bonusInstance)
        for (let i = 0; i < nodeCount + 1; i++) {
            tmp.push((await commonArray[i].parent()).valueOf())
            tmp.push((await tokenInstance.userTransfer(commonArray[i].address, value))['logs'][0]['args']['_value'])
            tmp.push((await tokenInstance.balanceOf(commonArray[i].address)).valueOf())
            tmp.push((await commonArray[i].infoTokensLeft()).valueOf())
            tmp.push(i < nodeCount?(await commonArray[i].infoIsActive()).valueOf():true)
            ideal.push(tokenInstance.address, value, value, value, i == nodeCount || i == currentNode)
        }
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })

    it('(Init...) Receiver', async () => {
        let tmp = []
        let ideal = []

        receiverInstance = await EtherReceiver.new(
            tokenInstance.address,
            nodeInstances.map(x => {
                return x.address
            }),
            bonusInstance.address,
            receiverBreakSeconds,
        )
        assert.ok(receiverInstance)

        tmp.push(await receiverInstance.getCurrentNode())
        ideal.push(currentNode + 1)

        tmp.push(await receiverInstance.crounsaleNodeCount())
        ideal.push(nodeInstances.length)
        let commonArray = nodeInstances.slice()
        commonArray.push(bonusInstance)
        for (let i = 0; i < commonArray.length; i++) {
            if (i != nodeInstances.length) {
                tmp.push((await receiverInstance.crounsaleNodes(i)) == commonArray[i].address)
            } else {
                tmp.push((await receiverInstance.bonusNode()) == commonArray[i].address)
            }
            ideal.push(true)
            tmp.push(
                (await commonArray[i].serviceGroupChange(receiverInstance.address, 3))['logs'][0]['args'][
                    '_newgroup'
                    ].valueOf(),
            )
            ideal.push(3)
            tmp.push(
                (await tokenInstance.serviceGroupChange(commonArray[i].address, 3))['logs'][0]['args'][
                    '_newgroup'
                    ].valueOf(),
            )
            ideal.push(3)
        }

        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('Test node end', async () => {
        let tmp = []
        tmp.push((await nodeInstances[currentNode].infoCountTokens(web3.toWei(0.001, 'ether'))).valueOf())
        tmp.push(await receiverInstance.getCurrentNode())
        tmp.push((await nodeInstances[currentNode].infoTokensLeft()).valueOf())
        tmp.push((await  nodeInstances[currentNode - 1].infoTokensLeft()).valueOf())
        await receiverInstance.sendTransaction({ from: accounts[1], value: web3.toWei(0.001, 'ether') })
        tmp.push((await nodeInstances[currentNode].infoTokensLeft()).valueOf())
        tmp.push((await  nodeInstances[currentNode - 1].infoTokensLeft()).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[1])).valueOf())
        tmp.push((await receiverInstance.getCurrentNode()).valueOf())
        console.log(tmp)
    })
    /*
    it('All token left test', async () => {
        let tmp = []
        let value = totalSupply / 10
        let realWeiPerToken = new BigNumber(weiPerToken).mul(0.9);
        let needleWei = realWeiPerToken.mul(value)
        tmp.push((await nodeInstances[currentNode].infoCountTokens(needleWei)).valueOf())
        tmp.push(await receiverInstance.getCurrentNode())
        tmp.push((await nodeInstances[currentNode].infoTokensLeft()).valueOf())
        tmp.push( await  nodeInstances[currentNode + 1].infoTokensLeft())
        await receiverInstance.sendTransaction({ from: accounts[1], value: needleWei })
        tmp.push((await nodeInstances[currentNode].infoTokensLeft()).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[1])).valueOf())
        tmp.push(await receiverInstance.getCurrentNode())
        tmp.push( await  nodeInstances[currentNode].serviceGetUnplanedEndDate())
        tmp.push( await  nodeInstances[currentNode + 1].startTime())
        tmp.push( await  receiverInstance.getBreakBetweenNode())
        tmp.push( await  nodeInstances[currentNode + 1].infoTime())
        tmp.push( await  nodeInstances[currentNode + 1].infoTokensLeft())
        console.log(tmp)
    })
    */
})