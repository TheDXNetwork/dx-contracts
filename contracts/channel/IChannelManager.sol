pragma solidity ^0.4.24;


interface IChannelManager {
    event ChannelOpened(
        address node,
        address from,
        uint256 deposit,
        uint64 timestamp
    );

    event ChannelClosed(
        address node,
        address from
    );
}