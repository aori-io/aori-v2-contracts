pragma solidity 0.8.24;
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeERC20} from "./libs/SafeERC20.sol";
import {AoriV2} from "./AoriV2.sol";

interface IBlast {
    // Note: the full interface for IBlast can be found below
    function configureClaimableGas() external;
    function configureGovernor(address governor) external;
}

/// @title AoriV2Blast
/// @notice An implementation of the settlement contract used for the Aori V2 protocol
/// @dev The current implementation regards a serverSigner that signs off on matching details
///      of which the private key behind this wallet should be protected. If the private key is
///      compromised, no funds can technically be stolen but orders will be matched in a way
///      that is not intended i.e FIFO.
contract AoriV2Blast is AoriV2 {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    constructor(address _serverSigner) AoriV2() {
        BLAST.configureClaimableGas();
        BLAST.configureGovernor(_serverSigner);
    }
}
