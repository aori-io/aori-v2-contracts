pragma solidity 0.8.24;

import {IZone} from "../interfaces/IZone.sol";
import {IClearing} from "../interfaces/IClearing.sol";

contract Vault is IZone {
    string public name;
    address public immutable clearing;
    address public manager;

    /*//////////////////////////////////////////////////////////////
                                 STRUCT
    //////////////////////////////////////////////////////////////*/

    struct Instruction {
        address to;
        uint256 value;
        bytes data;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, address _clearing, address _manager) {
        name = _name;
        clearing = _clearing;
        manager = _manager;
    }

    /*//////////////////////////////////////////////////////////////
                                HANDLERS
    //////////////////////////////////////////////////////////////*/

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory extraData
    ) external {
        /*//////////////////////////////////////////////////////////////
                                     ESCROW
        //////////////////////////////////////////////////////////////*/

        require(
            msg.sender == clearing,
            "Vault: Only clearing can call this function"
        );
        require(
            tx.origin == manager,
            "Vault: Only manager can call this function"
        );

        for (uint256 i = 0; i < orders.length; i++) {
            IClearing(clearing).escrow(orders[i]);
        }

        /*//////////////////////////////////////////////////////////////
                                PERFORM ACTIONS
        //////////////////////////////////////////////////////////////*/

        for (uint256 i = 0; i < orders.length; i++) {
            if (
                orders[i].order.offerer == manager &&
                orders[i].extraData.length > 0
            ) {
                // Decode instructions from order.extraData and execute
                Instruction[] memory instructions = abi.decode(
                    orders[i].extraData,
                    (Instruction[])
                );
                _execute(instructions);
            }
        }

        // Do final instructions
        Instruction[] memory instructions = abi.decode(
            extraData,
            (Instruction[])
        );
        _execute(instructions);

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
    ) external {
        if (tx.origin == manager) {
            // Decode instructions from extraData and execute
            Instruction[] memory instructions = abi.decode(
                extraData,
                (Instruction[])
            );
            _execute(instructions);
        }
    }

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

    function execute(Instruction[] memory instructions) external {
        require(tx.origin == manager, "Only manager can call this function");
        _execute(instructions);
    }

    /*//////////////////////////////////////////////////////////////
                                  MISC
    //////////////////////////////////////////////////////////////*/

    fallback() external payable {}

    receive() external payable {}
}
