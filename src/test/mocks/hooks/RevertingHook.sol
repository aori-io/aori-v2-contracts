pragma solidity 0.8.17;

import { IAoriHook } from "../../../interfaces/IAoriHook.sol";
import { IAoriV2 } from "../../../interfaces/IAoriV2.sol";

contract RevertingHook is IAoriHook {
    function beforeAoriTrade(IAoriV2.MatchingDetails calldata, bytes calldata) external returns (bool) {
        revert("Revert");
    }

    function afterAoriTrade(IAoriV2.MatchingDetails calldata, bytes calldata) external returns (bool) {
        revert("Revert");
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4 magicValue) {
        return 0x1626ba7e;
    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        return true;
    }
}