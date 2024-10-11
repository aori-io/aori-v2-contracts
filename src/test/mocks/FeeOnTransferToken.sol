// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {SimpleToken} from "./SimpleToken.sol";

contract FeeOnTransferToken is SimpleToken {
    uint256 public immutable feeInPercent;

    constructor(uint256 _feeInPercent) SimpleToken() {
        feeInPercent = _feeInPercent;
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 fee = (amount * feeInPercent) / 100;
        uint256 amountAfterFee = amount - fee;
        _burn(from, fee);
        return super.transferFrom(from, to, amountAfterFee);
    }
}
