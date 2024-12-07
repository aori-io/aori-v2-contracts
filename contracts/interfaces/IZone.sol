pragma solidity 0.8.24;

import {IClearing} from "./IClearing.sol";

interface IZone {
    // @dev This function can be used to choose who can access an off-chain channel
    // function verifyOwnership(
    //     bytes32 data,
    //     bytes memory signature
    // ) external view returns (bool);

    function name() external view returns (string memory);

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory extraData
    ) external;

    function handleDeposit(
        address from,
        address token,
        uint256 amount,
        bytes memory extraData
    ) external;
}
