pragma solidity ^0.4.24;

import "./ERC20.sol";


/**
 * @title ERC-20 extension for multiple recipients
 * @dev Extends the functionality of the ERC-20 standard token with the ability to transfer tokens
 * to multiple recipients in a single transaction.
 */
contract ERC20MultiRecipient is ERC20 {
    function transferMulti(address[] recipients, uint256[] values) public returns (bool) {
        require(recipients.length > 0);
        require(recipients.length == values.length);

        uint256 i;
        uint256 total;

        for (i = 0; i < values.length; i++) {
            total = total.add(values[i]);
        }

        require(total <= _balances[msg.sender]);

        _balances[msg.sender] = _balances[msg.sender].sub(total);

        for (i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0));

            _balances[recipients[i]] = _balances[recipients[i]].add(values[i]);

            emit Transfer(msg.sender, recipients[i], values[i]);
        }

        return true;
    }
}
