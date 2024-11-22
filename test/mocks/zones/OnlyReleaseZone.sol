pragma solidity 0.8.24;

import {IZone} from "contracts/interfaces/IZone.sol";
import {IClearing} from "contracts/interfaces/IClearing.sol";

contract OnlyReleaseZone is IZone {

    address public clearing;

    constructor(address _clearing) {
        clearing = _clearing;
    }

    function name() external view returns (string memory) {
        return "OnlyReleaseZone";
    }

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory extraData,
        bytes memory witness
    ) external {
        // Do nothing

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
