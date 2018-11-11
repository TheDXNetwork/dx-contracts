const assert = require('assert');
const { toBN } = require('./helpers');

const DXToken = artifacts.require('DXToken');


contract('DXToken', (accounts) => {
    let token;

    before(async () => {
        token = await DXToken.new();
    });

    it('should have 100,000,000 DXN in the first account', async () => {
        const balance = await token.balanceOf.call(accounts[0]);

        assert.strictEqual(balance.cmp(toBN('100000000000000000000000000')), 0);
    });
});
