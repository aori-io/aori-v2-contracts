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
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TradeSettled(string tradeId);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _clearing, address _manager) {
        clearing = _clearing;
        manager = _manager;
    }

    function handleSettlement(
        IClearing.SignedOrder[] memory orders,
        bytes memory extraData,
        bytes memory witness
    ) external {
        /*//////////////////////////////////////////////////////////////
                               VALIDATION
        //////////////////////////////////////////////////////////////*/

        require(
            msg.sender == clearing,
            "PrincipalMatch: Only clearing can call this function"
        );

        require(
            ClearingUtils.verifySequenceSignature(
                orders,
                extraData,
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

        // Do execution
        (Instruction[] memory instructions, string memory tradeId) = abi.decode(
            extraData,
            (Instruction[], string)
        );
        _execute(instructions);

        /*//////////////////////////////////////////////////////////////
                                    RELEASE
        //////////////////////////////////////////////////////////////*/

        for (uint256 i = 0; i < orders.length; i++) {
            IClearing(clearing).release(orders[i]);
        }

        /*//////////////////////////////////////////////////////////////
                                POST-SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        emit TradeSettled(tradeId);
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
