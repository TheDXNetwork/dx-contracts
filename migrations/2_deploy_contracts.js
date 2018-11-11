const DXToken = artifacts.require('./DXToken.sol');
const ChannelManager = artifacts.require('./ChannelManager.sol');

module.exports = function (deployer) {
    deployer.deploy(DXToken).then(() => {
        return deployer.deploy(ChannelManager, DXToken.address, 28 * 24 * 60 * 60); // 28 days timeout.
    });
};
