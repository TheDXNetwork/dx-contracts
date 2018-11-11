pragma solidity ^0.4.24;

import "./token/ERC20MultiRecipient.sol";
import "./token/ERC20Detailed.sol";


/**
 * @title DX Token
 */
contract DXToken is ERC20MultiRecipient, ERC20Detailed {
    string private constant NAME = "DX Network Token";

    string private constant SYMBOL = "DXN";

    uint8 private constant DECIMALS = 18;

    uint256 public constant TOTAL_SUPPLY = 100000000 * (10 ** uint256(DECIMALS));

    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor() public ERC20Detailed(NAME, SYMBOL, DECIMALS) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}