pragma solidity 0.8.24;

import {IZone} from "contracts/interfaces/IZone.sol";
import {IClearing} from "contracts/interfaces/IClearing.sol";
contract NoopZone is IZone {

    function name() external view returns (string memory) {
        return "NoopZone";
    }

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory extraData,
        bytes memory witness
    ) external {
        // Do nothing
    }

    function handleDeposit(
        address from,
        address token,
        uint256 amount,
        bytes memory extraData
    ) external {}
}
