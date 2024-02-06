
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract SimpleToken is ERC20 {
    constructor() ERC20("Mock", "MOCK", 18) {}

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}