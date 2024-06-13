// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {ICREATE3Factory} from "create3-factory/src/ICREATE3Factory.sol";
import { MultichainDeployScript } from "./MultichainDeploy.s.sol";
import "../src/AoriV2.sol";

contract DeployScript is Script, MultichainDeployScript {
    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployerAddress = vm.addr(deployerPrivateKey);
        bytes memory bytecode = abi.encodePacked(type(AoriV2).creationCode, abi.encode(deployerAddress));

        string memory AORI_VERSION = "Aori v2.1";

        /*//////////////////////////////////////////////////////////////
                                    TESTNETS
        //////////////////////////////////////////////////////////////*/

        // deployTo("goerli", AORI_VERSION, bytecode);
        // deployTo("sepolia", AORI_VERSION, bytecode);
        // deployTo("arbitrum-sepolia", AORI_VERSION, bytecode);
        // deployTo("arbitrum", AORI_VERSION, bytecode);
        // deployTo("mevm-m1", AORI_VERSION, bytecode);
        // deployTo("berachain-artio", AORI_VERSION, bytecode);

        /*//////////////////////////////////////////////////////////////
                                    MAINNETS
        //////////////////////////////////////////////////////////////*/

        // deployTo("arbitrum", AORI_VERSION, bytecode);
        deployTo("mainnet", AORI_VERSION, bytecode);
        // deployTo("optimism", AORI_VERSION, bytecode);
        // deployTo("polygon", AORI_VERSION, bytecode);
        // deployTo("blast", AORI_VERSION, bytecode);
        // deployTo("base", AORI_VERSION, bytecode);
        // deployTo("linea", AORI_VERSION, bytecode);
        // deployTo("mantle", AORI_VERSION, bytecode);
        // deployTo("gnosis", AORI_VERSION, bytecode);
        // deployTo("scroll", AORI_VERSION, bytecode);
        // deployTo("bsc", AORI_VERSION, bytecode);
        // deployTo("avalanche", AORI_VERSION, bytecode);
    }
}
