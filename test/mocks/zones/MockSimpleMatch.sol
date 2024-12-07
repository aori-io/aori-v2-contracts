pragma solidity 0.8.24;

import {IZone} from "contracts/interfaces/IZone.sol";
import {IClearing} from "contracts/interfaces/IClearing.sol";

contract MockSimpleMatch is IZone {
    address public clearing;

    constructor(address _clearing) {
        clearing = _clearing;
    }

    function name() external view returns (string memory) {
        return "MockSimpleMatch";
    }

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory
    ) external {
        // NOTE: This is only for testing purposes, so we don't check that msg.sender is clearing
        // require(msg.sender == clearing, "SimpleMatch: Only clearing can call this function");

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
