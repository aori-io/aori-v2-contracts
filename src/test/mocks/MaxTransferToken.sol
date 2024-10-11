// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {SimpleToken} from "./SimpleToken.sol";

contract MaxTransferToken is SimpleToken {
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (amount == type(uint256).max) {
            return super.transfer(to, balanceOf[msg.sender]);
        }

        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (amount == type(uint256).max) {
            return super.transferFrom(from, to, balanceOf[from]);
        }

        return super.transferFrom(from, to, amount);
    }
}
