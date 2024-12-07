pragma solidity 0.8.24;

import {IZone} from "../interfaces/IZone.sol";
import {IClearing} from "../interfaces/IClearing.sol";
import {ClearingUtils} from "../libs/ClearingUtils.sol";

struct Instruction {
    address to;
    uint256 value;
    bytes data;
}

contract PrincipalMatch is IZone {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    string public name = "PrincipalMatch";
    address public immutable clearing;
    address public manager;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _clearing, address _manager) {
        clearing = _clearing;
        manager = _manager;
    }

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory extraData
    ) external {
        /*//////////////////////////////////////////////////////////////
                                    VALIDATION
        //////////////////////////////////////////////////////////////*/

        require(
            msg.sender == clearing,
            "PrincipalMatch: Only clearing can call this function"
        );

        (Instruction[] memory instructions, bytes memory witness) = abi.decode(
            extraData,
            (Instruction[], bytes)
        );

        require(
            ClearingUtils.verifySequenceSignature(
                orders,
                abi.encode(instructions),
                witness,
                manager
            ),
            "PrincipalMatch: Invalid signature"
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
                               MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function setNewManager(address _newManager) external {
        require(manager == msg.sender, "Only manager can call this function");
        manager = _newManager;
    }

    /*//////////////////////////////////////////////////////////////
                                  MISC
    //////////////////////////////////////////////////////////////*/

    fallback() external payable {}

    receive() external payable {}
}
