const assert = require('assert');
const { web3, toDei, toBN, toAccount, deriveAccount, signReceipt, signTransaction } = require('./helpers');

const DXToken = artifacts.require('DXToken');
const ChannelManager = artifacts.require('ChannelManager');


contract('ChannelManager', (accounts) => {
    const NODE = toAccount(process.env.NODE_PRIVATE);
    const DEPOSIT = toDei('50');
    const RECIPIENTS = [
        '0x1000000000000000000000000000000000000000',
        '0x2000000000000000000000000000000000000000',
        '0x3000000000000000000000000000000000000000'
    ];
    const VALUES = ['0.1', '0.2', '0.3'].map(toDei);

    let node;
    let token;
    let channelManager;

    before(async () => {
        assert.strictEqual(RECIPIENTS.length, VALUES.length);

        token = await DXToken.new();
        channelManager = await ChannelManager.new(token.address, 28 * 24 * 60 * 60); // 28 days timeout.
    });

    it('should approve funds for channel manager', async () => {
        await token.approve(channelManager.address, DEPOSIT);
        const allowance = await token.allowance(accounts[0], channelManager.address);

        assert.strictEqual(DEPOSIT.cmp(allowance), 0);
    });

    it('should open channel to node', async () => {
        await channelManager.openChannel(NODE.address, DEPOSIT);

        const channel = await channelManager.getChannel.call(NODE.address);
        const timestamp = channel[0];
        const channelDeposit = channel[1];

        assert.strictEqual(DEPOSIT.cmp(channelDeposit), 0);
        assert.ok(!timestamp.isNeg() && !timestamp.isZero());
    });

    it('should settle channel', async () => {
        // Client should provide a signature from the node.
        const signature = signReceipt(RECIPIENTS, VALUES, NODE);
        await channelManager.settleChannel(NODE.address, RECIPIENTS, VALUES, signature);

        // Check if recipients got paid.
        const total = toBN(0);
        for (let i = 0; i < RECIPIENTS.length; i++) {
            const balance = await token.balanceOf.call(RECIPIENTS[i]);
            assert.strictEqual(VALUES[i].cmp(balance), 0);

            total.add(VALUES[i]);
        }

        // Check if deposit is refunded.
        const refundedBalance = await token.balanceOf(accounts[0]);
        assert.ok(refundedBalance.add(total).cmp(DEPOSIT));

        // Check if channel is closed.
        const channel = await channelManager.getChannel.call(NODE.address);
        const timestamp = channel[0];

        assert.ok(timestamp.isZero());
    });

    it('should close channel after timeout', async () => {
        channelManager = await ChannelManager.new(token.address, 2); // 2 second timeout.

        await token.approve(channelManager.address, DEPOSIT);
        await channelManager.openChannel(NODE.address, DEPOSIT);

        const account = deriveAccount(0);
        const signature = signReceipt(RECIPIENTS, VALUES, account);

        const tx = {
            nonce: web3.eth.getTransactionCount(NODE.address),
            from: NODE.address,
            to: channelManager.address,
            data: web3.eth.abi.encodeFunctionCall(
                channelManager.abi.find(el => el.name === 'closeChannel'),
                [account.address, RECIPIENTS, VALUES.map(x => x.toString(10)), signature]
            ),
            gas: 1000000
        };

        let signedTx = await web3.eth.accounts.signTransaction(tx, NODE.privateKey);

        let caughtError = false;
        try {
            // Try to close before timeout, should revert.
            await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
        } catch (err) {
            caughtError = true;
        }

        assert.ok(caughtError);

        // Close after timeout.
        await new Promise(resolve => setTimeout(resolve, 3 * 1000));

        tx.nonce++;
        signedTx = await web3.eth.accounts.signTransaction(tx, NODE.privateKey);
        await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    });
});