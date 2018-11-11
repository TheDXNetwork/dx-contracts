pragma solidity ^0.4.24;

import "../math/SafeMath.sol";
import "../token/ERC20MultiRecipient.sol";
import "./IChannelManager.sol";


/**
 * @title Channel manager contract with support for one-to-many payments.
 */
contract ChannelManager is IChannelManager {
    using SafeMath for uint256;

    // Structs benefit from using smaller variables as they are stored packed.
    struct Channel {
        address node;
        uint192 deposit;
        uint64 timestamp;
    }

    uint64 private _channelTimeout;

    ERC20MultiRecipient private _token;

    mapping (bytes32 => Channel) private _channels;

    /**
     * @param token Address of the ERC-20 compatible token contract.
     * @param channelTimeout Channel timeout in seconds.
     */
    constructor(address token, uint64 channelTimeout) public {
        _channelTimeout = channelTimeout;
        _token = ERC20MultiRecipient(token);
    }

    /**
     * @dev Opens a channel between a client and a manager node.
     * @param node Address of the manager node.
     * @param deposit Amount to deposit.
     */
    function openChannel(address node, uint256 deposit) public returns (bool) {
        require(node != address(0));
        require(node != msg.sender);
        require(deposit > 0);

        bytes32 key = _channelKey(msg.sender, node);

        if (_channels[key].timestamp == 0) {
            uint64 timestamp = uint64(block.timestamp);
            _channels[key] = Channel(node, uint192(deposit), timestamp);

            emit ChannelOpened(node, msg.sender, deposit, timestamp);

            _token.transferFrom(msg.sender, address(this), deposit);
        }

        return true;
    }

    /**
     * @dev Returns the deposit amount left for the caller's channel.
     * @param node Address of the manager node.
     * @return Creation timestamp and deposit of the channel.
     */
    function getChannel(address node) public view returns (uint64, uint256) {
        require(node != address(0));

        bytes32 key = _channelKey(msg.sender, node);
        return (_channels[key].timestamp, uint256(_channels[key].deposit));
    }

    /**
     * @dev Settles the channel provided the caller has a valid signature from channel's node.
     */
    function settleChannel(address node, address[] recipients, uint256[] values, bytes nodesig) public returns (bool) {
        require(node != address(0));
        require(recipients.length > 0);
        require(recipients.length == values.length);

        bytes32 key = _channelKey(msg.sender, node);

        require(_channels[key].timestamp > 0);
        require(_channels[key].node == node);

        address signer = _recoverAddress(recipients, values, nodesig);
        require(node == signer);

        _settleChannel(msg.sender, node, key, recipients, values);

        return true;
    }

    /**
     * @dev Closes the channel after the channel timed out provided the node has a valid signature from the client.
     */
    function closeChannel(address from, address[] recipients, uint256[] values, bytes clientsig) public returns (bool) {
        require(from != address(0));
        require(recipients.length > 0);
        require(recipients.length == values.length);

        bytes32 key = _channelKey(from, msg.sender);

        require(_channels[key].timestamp > 0);
        require(_channels[key].node == msg.sender);

        uint256 channelOpenTimestamp = block.timestamp.sub(_channels[key].timestamp);

        require(_channelTimeout < channelOpenTimestamp);

        address signer = _recoverAddress(recipients, values, clientsig);
        require(from == signer);

        _settleChannel(from, msg.sender, key, recipients, values);

        return true;
    }

    function _settleChannel(address from, address node, bytes32 key, address[] recipients, uint256[] values) private {
        uint256 total;

        for (uint256 i = 0; i < values.length; i++) {
            total = total.add(values[i]);
        }

        require(total <= _channels[key].deposit);

        uint256 refund = uint256(_channels[key].deposit).sub(total);

        delete _channels[key];
        emit ChannelClosed(node, from);

        _token.transferMulti(recipients, values);
        _token.transfer(from, refund);
    }

    function _channelKey(address from, address node) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(from, node));
    }

    function _recoverAddress(address[] recipients, uint256[] values, bytes signature) private pure returns (address) {
        require(signature.length == 0x41); // 0x20 + 0x20 + 0x01

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // First 32 bytes contain array length.
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))

            // Convert classic ECDSA recovery identifier to yellow paper variant.
            if lt(v, 0x1b) {
                v := add(v, 0x1b)
            }
        }

        require(v == 0x1b || v == 0x1c);

        bytes32 message = keccak256(abi.encodePacked(recipients, values));
        return ecrecover(message, v, r, s);
    }
}
