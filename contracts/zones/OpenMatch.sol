pragma solidity 0.8.24;

import {IZone} from "../interfaces/IZone.sol";
import {IClearing} from "../interfaces/IClearing.sol";
import {ClearingUtils} from "../libs/ClearingUtils.sol";

struct Instruction {
    address to;
    uint256 value;
    bytes data;
}

contract OpenMatch is IZone {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    string public name = "OpenMatch";
    address public immutable clearing;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _clearing) {
        clearing = _clearing;
    }

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory extraData,
        bytes memory
    ) external {
        /*//////////////////////////////////////////////////////////////
                               VALIDATION
        //////////////////////////////////////////////////////////////*/

        require(
            msg.sender == clearing,
            "OpenMatch: Only clearing can call this function"
        );

        /*//////////////////////////////////////////////////////////////
                                     ESCROW
        //////////////////////////////////////////////////////////////*/

        for (uint256 i = 0; i < orders.length; i++) {
            IClearing(clearing).escrow(orders[i]);
        }

        /*//////////////////////////////////////////////////////////////
                                PERFORM ACTIONS
        //////////////////////////////////////////////////////////////*/

        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[i].extraData.length > 0) {
                // Decode instructions from order.extraData and execute
                Instruction[] memory instructions = abi.decode(
                    orders[i].extraData,
                    (Instruction[])
                );
                _execute(instructions);
            }
        }

        // Do execution
        if (extraData.length > 0) {
            Instruction[] memory instructions = abi.decode(
                extraData,
                (Instruction[])
            );
            _execute(instructions);
        }

        /*//////////////////////////////////////////////////////////////
                                    RELEASE
        //////////////////////////////////////////////////////////////*/

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

    function _execute(Instruction[] memory instructions) internal {
        uint256 length = instructions.length;
        for (uint256 i; i < length; i++) {
            address to = instructions[i].to;
            uint256 value = instructions[i].value;
            bytes memory _data = instructions[i].data;

            // If call to external function is not successful, revert
            (bool success, ) = to.call{value: value}(_data);
            require(success, "Call to external function failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  MISC
    //////////////////////////////////////////////////////////////*/

    fallback() external payable {}

    receive() external payable {}
}
