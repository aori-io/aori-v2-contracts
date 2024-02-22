pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ICREATE3Factory} from "create3-factory/src/ICREATE3Factory.sol";

contract MultichainDeployScript is Script {
    function deployTo(string memory network, string memory tag, bytes memory bytecode) internal {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployerAddress = vm.addr(deployerPrivateKey);
        address create3FactoryAddress = vm.envAddress("CREATE3FACTORY_ADDRESS");
        bytes32 salt = keccak256(bytes(tag));

        vm.createSelectFork(network);
        address addressToDeployTo = ICREATE3Factory(create3FactoryAddress).getDeployed(
            deployerAddress,
            salt
        );

        // if the contract doesn't exist, deploy it
        if (addressToDeployTo.code.length == 0) {
            vm.startBroadcast(deployerPrivateKey);
            ICREATE3Factory(create3FactoryAddress).deploy(
                salt,
                bytecode
            );
            vm.stopBroadcast();

            console.log("%s deployed to address %s on chain %s", tag, addressToDeployTo, network);
        } else {
            console.log("%s already deployed to address %s on chain %s", tag, addressToDeployTo, network);
        }
    }
}