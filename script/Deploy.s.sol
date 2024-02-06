// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {ICREATE3Factory} from "create3-factory/src/ICREATE3Factory.sol";
import "../src/AoriV2.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployerAddress = vm.addr(deployerPrivateKey);
        address create3FactoryAddress = vm.envAddress("CREATE3FACTORY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        ICREATE3Factory(create3FactoryAddress).deploy(
            keccak256(bytes("Aori V2.0")),
            abi.encodePacked(
                type(AoriV2).creationCode,
                abi.encode(deployerAddress)
            )
        );

        vm.stopBroadcast();
    }
}
