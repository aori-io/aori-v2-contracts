pragma solidity 0.8.17;

import { IAoriHook } from "../../../interfaces/IAoriHook.sol";
import { IAoriV2 } from "../../../interfaces/IAoriV2.sol";

contract TrickFailingHook is IAoriHook {
    function beforeAoriTrade(IAoriV2.MatchingDetails calldata, bytes calldata) external returns (bool) {
        return true;
    }

    function afterAoriTrade(IAoriV2.MatchingDetails calldata, bytes calldata) external returns (bool) {
        return false;
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4 magicValue) {
        return 0x1626ba7e;
    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        return true;
    }
}