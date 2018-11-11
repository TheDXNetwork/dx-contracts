const bip39 = require('bip39');
const hdkey = require('ethereumjs-wallet/hdkey');
const Account = require('eth-lib/lib/account');
const Tx = require('eth-lib/lib/transaction');
const Web3 = require('web3');

const web3 = new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:8565'));


module.exports.toBN = function (n) {
    if (Web3.utils.isBN(n)) return n;

    return Web3.utils.toBN(n);
};

module.exports.toDei = function (dxn) {
    return Web3.utils.toBN(Web3.utils.toWei(dxn, 'ether'));
};

module.exports.signReceipt = function (recipients, values, account) {
    const len = recipients.length;

    // Even though the arrays are dynamic, use static arrays to emulate abi.encodePacked behaviour.
    const encoded = web3.eth.abi.encodeParameters(
        [`address[${len}]`, `uint256[${len}]`],
        [recipients, values.map(x => x.toString(10))]
    );
    const hash = web3.utils.sha3(encoded);

    return Account.sign(hash, account.privateKey);
};

module.exports.signTransaction = function (tx, account) {
    return Tx.sign(tx, account);
};

module.exports.toAccount = function (privateKey) {
    return Account.fromPrivate(privateKey);
};

module.exports.deriveAccount = function (i) {
    const hdwallet = hdkey.fromMasterSeed(bip39.mnemonicToSeed(process.env.MNEMONIC));
    const path = "m/44'/60'/0'/0";

    const wallet = hdwallet.derivePath(`${path}/${i}`).getWallet();

    return {
        address: `0x${wallet.getAddress().toString('hex')}`,
        privateKey: `0x${wallet.getPrivateKey().toString('hex')}`
    }
};

module.exports.web3 = web3;