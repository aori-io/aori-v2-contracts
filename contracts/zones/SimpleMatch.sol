pragma solidity 0.8.24;

import {IZone} from "contracts/interfaces/IZone.sol";
import {IClearing} from "contracts/interfaces/IClearing.sol";

contract SimpleMatch is IZone {
    address public immutable clearing;

    constructor(address _clearing) {
        clearing = _clearing;
    }

    function name() external view returns (string memory) {
        return "SimpleMatch";
    }

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory
    ) external {
        require(
            msg.sender == clearing,
            "SimpleMatch: Only clearing can call this function"
        );

        for (uint256 i = 0; i < orders.length; i++) {
            IClearing(clearing).escrow(orders[i]);
        }

        for (uint256 i = 0; i < orders.length; i++) {
            IClearing(clearing).release(orders[i]);
        }
    }

    function handleDeposit(
        address from,
        address token,
        uint256 amount,
        bytes memory extraData
    ) external {}
}
