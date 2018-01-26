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
    let nodeSeconds = 600
    let receiverBreakSeconds = 600
    let date = new Date()
    let tokenInstance
    let nodeInstances = []
    let bonusInstance
    let receiverInstance

    it('(Init...) Token', async () => {
        tokenInstance = await AutoCoin.new(name, symbol, decimals, weiPerToken, totalSupply, { from: accounts[0] })
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
                0,
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
            tmp.push(i < nodeCount?(await commonArray[i].infoIsActive()).valueOf(): true)
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

    it('(Admin part..) Token', async () => {
        let tmp = []

        tmp.push((await tokenInstance.serviceGroupChange(accounts[1], 4))['logs'][0]['args']['_newgroup'].valueOf())
        tmp.push((await tokenInstance.serviceGroupChange(accounts[1], 0))['logs'][0]['args']['_newgroup'].valueOf())
        tmp.push((await tokenInstance.settingsSetWeiPerMinToken(weiPerToken * 2))['logs'][0]['args']['_text'].valueOf())
        tmp.push((await tokenInstance.weiPerMinToken()).valueOf())

        let ideal = [4, 0, 'changed', weiPerToken * 2]
        let result = validateValues(tmp, ideal)

        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Admin part..) Current node ', async () => {
        let tmp = []

        tmp.push(
            (await nodeInstances[currentNode].serviceGroupChange(accounts[1], 4))['logs'][0]['args'][
                '_newgroup'
            ].valueOf(),
        )
        tmp.push(
            (await nodeInstances[currentNode].serviceGroupChange(accounts[1], 0))['logs'][0]['args'][
                '_newgroup'
            ].valueOf(),
        )
        tmp.push((await nodeInstances[currentNode].infoActiveOnDate(time(date))).valueOf())

        let ideal = [4, 0, true]
        let result = validateValues(tmp, ideal)

        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Admin part..) Receiver ', async () => {
        let tmp = []

        tmp.push((await receiverInstance.serviceGroupChange(accounts[1], 4))['logs'][0]['args']['_newgroup'].valueOf())
        tmp.push((await receiverInstance.serviceGroupChange(accounts[1], 0))['logs'][0]['args']['_newgroup'].valueOf())
        tmp.push((await receiverInstance.crounsaleNodeCount()).valueOf())

        let ideal = [4, 0, nodeInstances.length]
        let result = validateValues(tmp, ideal)

        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Admin part..) [not-admin] Token', async () => {
        let tmp = []

        await tokenInstance.serviceGroupChange(accounts[2], 4, { from: accounts[2] }).catch(err => {
            tmp[0] = true
        })

        await tokenInstance.serviceGroupGet.call(accounts[1], { from: accounts[1] }).catch(err => {
            tmp[1] = true
        })

        await tokenInstance.settingsSetWeiPerMinToken(weiPerToken * 2, { from: accounts[2] }).catch(err => {
            tmp[2] = true
        })
        let ideal = [true, true, true]
        let result = validateValues(tmp, ideal)

        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Admin part..) [not-admin] Current node ', async () => {
        let tmp = []

        await nodeInstances[currentNode].serviceGroupChange(accounts[2], 4, { from: accounts[2] }).catch(err => {
            tmp[0] = true
        })

        await nodeInstances[currentNode].serviceGroupGet.call(accounts[1], { from: accounts[1] }).catch(err => {
            tmp[1] = true
        })

        await nodeInstances[currentNode].infoActiveOnDate(time(date), { from: accounts[2] }).catch(err => {
            tmp[2] = true
        })

        let ideal = [true, true, true]
        let result = validateValues(tmp, ideal)

        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Admin part..) [not-admin] Receiver ', async () => {
        let tmp = []

        await receiverInstance.serviceGroupChange(accounts[2], 4, { from: accounts[2] }).catch(err => {
            tmp[0] = true
        })

        await receiverInstance.serviceGroupGet.call(accounts[1], { from: accounts[1] }).catch(err => {
            tmp[1] = true
        })

        await receiverInstance.crounsaleNodeCount({ from: accounts[2] }).catch(err => {
            tmp[2] = true
        })
        let ideal = [true, true, true]
        let result = validateValues(tmp, ideal)

        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })

    it('(Transfer..) Token', async () => {
        let tmp = []
        tmp.push((await tokenInstance.balanceOf(accounts[0])).valueOf())
        tmp.push((await tokenInstance.userTransfer(accounts[1], 10))['logs'][0]['args']['_value'])
        tmp.push((await tokenInstance.balanceOf(accounts[0])).valueOf())
        await tokenInstance.settingsSwitchTransferAccess()
        tmp.push((await tokenInstance.transferEnable()).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[1])).valueOf())
        tmp.push(
            (await tokenInstance.userTransfer(accounts[0], 10, { from: accounts[1] }))['logs'][0]['args']['_value'],
        )
        tmp.push((await tokenInstance.balanceOf(accounts[1])).valueOf())
        await tokenInstance.settingsSwitchTransferAccess()
        tmp.push((await tokenInstance.transferEnable()).valueOf())

        let ideal = [tmp[0], 10, tmp[0] - 10, true, 10, 10, 0, false]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Transfer..) Node', async () => {
        let tmp = []
        tmp.push((await nodeInstances[currentNode].infoTokensLeft()).valueOf())
        tmp.push((await nodeInstances[currentNode].infoAccountPurchaseCount(accounts[1])).valueOf())
        tmp.push((await nodeInstances[currentNode].transfer(accounts[1], 10, true))['logs'][0]['args']['_value'])
        tmp.push((await nodeInstances[currentNode].infoTokensLeft()).valueOf())
        tmp.push((await nodeInstances[currentNode].infoAccountPurchaseCount(accounts[1])).valueOf())
        tmp.push((await nodeInstances[currentNode].infoAccountTokens(accounts[1], 0)).valueOf()[1])

        let ideal = [tmp[0], 0, 10, tmp[0] - 10, 1, 10]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Transfer..) Receiver', async () => {
        let tmp = []
        tmp.push((await nodeInstances[currentNode].infoTokensLeft()).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[1])).valueOf())
        await receiverInstance.transfer(accounts[1], 10)
        tmp.push((await nodeInstances[currentNode].infoTokensLeft()).valueOf())
        tmp.push((await bonusInstance.infoTokensLeft()).valueOf())
        await receiverInstance.transferBonus(accounts[1], 5)
        tmp.push((await bonusInstance.infoTokensLeft()).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[1])).valueOf())

        let ideal = [tmp[0], tmp[1], tmp[0] - 10, tmp[3], tmp[3] - 5, new BigNumber(tmp[1]).add(15)]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Approve & TransferFrom...) Token', async () => {
        let tmp = []
        let value = 10
        let subvalue = 5

        await tokenInstance.settingsSwitchTransferAccess()
        tmp.push((await tokenInstance.transferEnable()).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[0])).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[1])).valueOf())
        tmp.push((await tokenInstance.userApprove(accounts[1], 0, value))['logs'][0]['args']['_value'])
        tmp.push((await tokenInstance.allowance(accounts[0], accounts[1])).valueOf())
        tmp.push(
            (await tokenInstance.userTransferFrom(accounts[0], accounts[1], subvalue, { from: accounts[1] }))[
                'logs'
            ][0]['args']['_value'],
        )
        tmp.push((await tokenInstance.allowance.call(accounts[0], accounts[1])).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[0])).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[1])).valueOf())
        await tokenInstance.settingsSwitchTransferAccess()
        tmp.push((await tokenInstance.transferEnable()).valueOf())

        let ideal = [
            true,
            tmp[1],
            tmp[2],
            value,
            value,
            subvalue,
            value - subvalue,
            tmp[1] - subvalue,
            new BigNumber(tmp[2]).add(subvalue),
            false,
        ]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Change owner...) Token', async () => {
        let tmp = []

        tmp.push(
            (await tokenInstance.serviceChangeOwner(accounts[1], { from: accounts[0] }))['logs'][0]['args'][
                '_newgroup'
            ].valueOf(),
        )
        tmp.push(
            (await tokenInstance.serviceChangeOwner(accounts[1], { from: accounts[1] }))['logs'][0]['args'][
                '_newgroup'
            ].valueOf(),
        )
        tmp.push(
            (await tokenInstance.serviceChangeOwner(accounts[0], { from: accounts[1] }))['logs'][0]['args'][
                '_newgroup'
            ].valueOf(),
        )
        tmp.push(
            (await tokenInstance.serviceChangeOwner(accounts[0], { from: accounts[0] }))['logs'][0]['args'][
                '_newgroup'
            ].valueOf(),
        )

        let ideal = [2, 9, 2, 9]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Buying token...) Receiver', async () => {
        let tmp = []
        let svalue = 0.1
        let mantiss = 1000000000000000000

        tmp.push((await tokenInstance.balanceOf(accounts[0])).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[3])).valueOf())
        console.log(await receiverInstance.sendTransaction({ from: accounts[3], value: web3.toWei(svalue, 'ether') }))
        tmp.push((await nodeInstances[currentNode].infoCountTokens(web3.toWei(svalue, 'ether'))).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[3])).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[0])).valueOf())
        tmp.push((await tokenInstance.weiPerMinToken()).valueOf())
        console.log((await web3.eth.getBalance(accounts[0])).valueOf())
        console.log((await web3.eth.getBalance(receiverInstance.address)).valueOf())
        console.log((await receiverInstance.serviceGetWei()).valueOf())
        console.log((await web3.eth.getBalance(receiverInstance.address)).valueOf())
        console.log((await web3.eth.getBalance(accounts[0])).valueOf())

        let floorTmp = new BigNumber(svalue)
            .mul(mantiss)
            .div(tmp[5])
            .floor()
        let ideal = [tmp[0], tmp[1], floorTmp, new BigNumber(tmp[1]).add(floorTmp), tmp[4], tmp[5]]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })

    it('(Buying token...) [stress-test] Receiver', async () => {
        let tmp = []
        let svalue = 0.000000000001
        let mantiss = 1000000000000000000

        tmp.push((await tokenInstance.balanceOf(accounts[0])).valueOf())
        tmp.push((await tokenInstance.balanceOf(accounts[2])).valueOf())
        await receiverInstance
            .sendTransaction({ from: accounts[3], value: web3.toWei(1000500000000, 'ether') })
            .catch(err => {
                tmp.push(true)
            })

        tmp.push((await tokenInstance.balanceOf(accounts[2])).valueOf())
        let ideal = [tmp[0], tmp[1], true, tmp[1]]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })

    it('[stress-test] Token', async () => {
        let tmp = []
        let svalue = 1000000

        //Overflow
        await tokenInstance.userApprove(accounts[1], await tokenInstance.allowance(accounts[0],accounts[1]), MAX_UINT256).catch(err => {
            tmp.push(true)
        })

        //Empty balances + approve (= allowance > balance)
        await tokenInstance.userTransferFrom(accounts[4], accounts[5], svalue).catch(err => {
            tmp.push(true)
        })

        await tokenInstance.userTransferFrom(accounts[0], accounts[2], MAX_UINT256).catch(err => {
            tmp.push(true)
        })

        tokenInstance.userApprove(accounts[1],await tokenInstance.allowance(accounts[0],accounts[1]), 1000)

        await tokenInstance.settingsSwitchTransferAccess()
        tmp.push((await tokenInstance.transferEnable()).valueOf())
        tmp.push(
            (await tokenInstance.userTransferFrom(accounts[0], accounts[1], 1000, { from: accounts[1] }))['logs'][0][
                'args'
            ]['_value']
        )

        await tokenInstance.settingsSwitchTransferAccess()
        tmp.push((await tokenInstance.transferEnable()).valueOf())

        let ideal = [true, true,true, true, 1000,false]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })

    it('(Changing...) Receiver', async () => {
        let tmp = []
        let newNode = await Node.new(tokenInstance.address, time(date) + 2 * (nodeSeconds + receiverBreakSeconds), nodeSeconds, 5, {
            from: accounts[0],
        })
        newNode.serviceGroupChange(receiverInstance.address, 3, { from: accounts[0] })
        let removedAddress = nodeInstances[currentNode + 1].address

        let ideal = []
        for (let i = 0; i < await receiverInstance.crounsaleNodeCount(); i++) {
            ideal.push(await receiverInstance.crounsaleNodes(i))
        }

        ideal[currentNode + 1] = ideal.pop()
        ideal[currentNode + 2] = newNode.address
        ideal.push(removedAddress)

        await receiverInstance.removeNode(removedAddress, { from: accounts[0] })
        let tempNode = Object.assign({}, nodeInstances[currentNode + 1])
        nodeInstances[currentNode + 1] = nodeInstances.pop()
        await receiverInstance.replaceNode(nodeInstances[currentNode + 2].address, newNode.address, { from: accounts[0] })
        nodeInstances[currentNode + 2] = newNode;
        await receiverInstance.addNode(removedAddress, { from: accounts[0] })
        nodeInstances.push(tempNode)

        for (let i = 0; i < await receiverInstance.crounsaleNodeCount(); i++) {
            tmp.push(await receiverInstance.crounsaleNodes(i))
        }

        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    it('(Changing...) [stress-test] Receiver', async () => {
        let tmp = []
        let newNode = await Node.new(tokenInstance.address, time(date) + 2 * (nodeSeconds + receiverBreakSeconds), nodeSeconds, 5, {
            from: accounts[0],
        })
        newNode.serviceGroupChange(receiverInstance.address, 3, { from: accounts[0] })

        await receiverInstance.removeNode(newNode.address, { from: accounts[0] }).catch(err => {
            tmp.push(true)
        })
        await receiverInstance.replaceNode(nodeInstances[currentNode + 2].address, nodeInstances[currentNode].address, { from: accounts[0] }).catch(err => {
            tmp.push(true)
        })
        await receiverInstance.addNode(nodeInstances[currentNode + 2].address, { from: accounts[0] }).catch(err => {
            tmp.push(true)
        })
        let ideal = [true,true,true]
        let result = validateValues(tmp, ideal)
        assert.equal(result, ideal.length, ' only few tests were passed :c')
    })
    /*
    it('Send tokens', async () => {
        let temp = []
        const trValue = 1000000000
        temp.push(await tokenInstance.balanceOf(accounts[0]))

        for (let i = 0; i < nodeCount; i++) {
            temp.push(
                (await tokenInstance.userTransfer(nodeInstances[i].address, trValue, { from: accounts[0] }))['logs'][0][
                    'args'
                ]['_value'].valueOf(),
            )
        }
        temp.push(
            (await tokenInstance.userTransfer(bonusInstance.address, trValue, { from: accounts[0] }))['logs'][0][
                'args'
            ]['_value'].valueOf(),
        )
        temp.push(await tokenInstance.balanceOf(accounts[0]))
        console.log(temp)
        const ideal = [trValue, trValue, trValue, trValue, trValue, trValue]
    })

    it('Test receiver buy', async () => {
        let temp = []
        const currentNode = (await receiverInstance.getCurrentNode({ from: accounts[0] })).valueOf() - 1
        console.log('______1')
        console.log(await receiverInstance.totalBought())
        console.log('Current node: ' + currentNode)
        console.log(receiverInstance.address)
        temp.push(await receiverInstance.crounsaleNodeCount())
        temp.push(await tokenInstance.balanceOf(bonusInstance.address))
        temp.push(await tokenInstance.balanceOf(await receiverInstance.crounsaleNodes(currentNode)))
        temp.push(await tokenInstance.balanceOf(accounts[1]))
        temp.push(await tokenInstance.balanceOf(accounts[0]))

        console.log(await receiverInstance.sendTransaction({ from: accounts[1], value: 100 * 10000 }))
        console.log('______2_ 100')
        console.log(await receiverInstance.totalBought())
        console.log(await tokenInstance.balanceOf.call(accounts[1]))
        temp.push(await tokenInstance.balanceOf(accounts[0]))
        temp.push(await tokenInstance.balanceOf(await receiverInstance.crounsaleNodes(currentNode)))
        console.log((await receiverInstance.getNodeAccountPurchaseCount(accounts[1], currentNode)).valueOf())
        console.log(await receiverInstance.getNodeBalance(accounts[1], currentNode, 0))

        console.log(await bonusInstance.isActive.call())
        console.log(await tokenInstance.balanceOf.call(bonusInstance.address))
        console.log(await receiverInstance.transferBonus(accounts[1], 100))
        //await new Promise(resolve => setTimeout(resolve, 10000))
        console.log(await tokenInstance.balanceOf.call(bonusInstance.address))
        console.log('______3_ 200')
        console.log(await receiverInstance.totalBought())
        console.log(await receiverInstance.transfer(accounts[1], 100))
        console.log('______4_ 300')
        console.log(await receiverInstance.totalBought())

        temp.push(await tokenInstance.balanceOf(await receiverInstance.crounsaleNodes(currentNode)))
        temp.push(await tokenInstance.balanceOf(accounts[1]))

        await tokenInstance.userTransfer(accounts[2], 50, { from: accounts[1] })

        temp.push(await tokenInstance.balanceOf(accounts[1]))

        temp.push(await tokenInstance.settingsSwitchTransferAccess({ from: accounts[0] }))

        await tokenInstance.userTransfer(accounts[2], 50, { from: accounts[1] })

        temp.push(await tokenInstance.balanceOf(accounts[1]))
        temp.push(await tokenInstance.balanceOf(accounts[2]))

        console.log('______')
        console.log(await receiverInstance.totalBought())
    })

    it('Test getNodeByDate', async () => {
        let cTime = time(new Date())
        console.log(cTime)
        let index = (await receiverInstance.getNodeByDate(cTime)).valueOf()
        console.log(index - 1)
        let node2 = await receiverInstance.crounsaleNodes(index - 1)
        console.log(node2)
        console.log(temp)
    })
    */
})
