pragma solidity 0.8.17;

import "./IAoriV2.sol";

interface IAoriHook {
    function beforeAoriTrade(IAoriV2.MatchingDetails calldata matching, bytes calldata hookData) external returns (bool);
    function afterAoriTrade(IAoriV2.MatchingDetails calldata matching, bytes calldata hookData) external returns (bool);
}