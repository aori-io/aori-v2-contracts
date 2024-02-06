pragma solidity 0.8.17;

import { IERC1271 } from "../../../interfaces/IERC1271.sol";
import { IAoriHook } from "../../../interfaces/IAoriHook.sol";
import { IAoriV2 } from "../../../interfaces/IAoriV2.sol";

contract UnauthedHook is IAoriHook, IERC1271 {
    function beforeAoriTrade(IAoriV2.MatchingDetails calldata, bytes calldata) external returns (bool) {
        return true;   
    }

    function afterAoriTrade(IAoriV2.MatchingDetails calldata, bytes calldata) external returns (bool) {
        return true;
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4 magicValue) {
        return 0x00000000;
    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        return true;
    }
}