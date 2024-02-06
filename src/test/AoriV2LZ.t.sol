// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {SimpleToken} from "./mocks/SimpleToken.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {SimpleHook} from "./mocks/hooks/SimpleHook.sol";
import {RevertingHook} from "./mocks/hooks/RevertingHook.sol";
import {FailingHook} from "./mocks/hooks/FailingHook.sol";
import {TrickFailingHook} from "./mocks/hooks/TrickFailingHook.sol";
import {UnauthedHook} from "./mocks/hooks/UnauthedHook.sol";
import {SimpleFlashLoanReceiver} from "./mocks/flashloan/SimpleFlashLoanReceiver.sol";
import {RevertingFlashLoanReceiver} from "./mocks/flashloan/RevertingFlashLoanReceiver.sol";

import { AoriV2Test } from "./AoriV2.t.sol";

import { AoriV2 } from "../AoriV2LZ.sol";
import { BaseFixture } from "./BaseFixture.sol";
import { IAoriV2 } from "../interfaces/IAoriV2.sol";

interface IERC20Mintable is IERC20 {
    function mint(uint256 amount) external;
}

contract AoriV2TLZTest is AoriV2Test {

    function setUp() public override {
        utils = new Utilities();
        users = utils.createUsers(5);

        SERVER_WALLET = address(vm.addr(SERVER_PRIVATE_KEY));
        FAKE_SERVER_WALLET = address(vm.addr(FAKE_SERVER_PRIVATE_KEY));
        MAKER_WALLET = address(vm.addr(MAKER_PRIVATE_KEY));
        FAKE_MAKER_WALLET = address(vm.addr(FAKE_MAKER_PRIVATE_KEY));
        TAKER_WALLET = address(vm.addr(TAKER_PRIVATE_KEY));
        FAKE_TAKER_WALLET = address(vm.addr(FAKE_TAKER_PRIVATE_KEY));
        SEARCHER_WALLET = address(vm.addr(SEARCHER_PRIVATE_KEY));

        aori = new AoriV2(0x464570adA09869d8741132183721B4f0769a0287, SERVER_WALLET);

        // Setup hook contracts
        simpleHook = new SimpleHook();
        revertHook = new RevertingHook();
        failingHook = new FailingHook();
        trickFailingHook = new TrickFailingHook();
        unauthedHook = new UnauthedHook();

        // Setup flashloan receiver
        flashloanReceiver = new SimpleFlashLoanReceiver();
        revertFlashloanReceiver = new RevertingFlashLoanReceiver();

        vm.label(address(aori), "AoriV2LZ");

        vm.label(SERVER_WALLET, "Server Wallet");
        vm.label(FAKE_SERVER_WALLET, "Fake Server Wallet");
        vm.label(MAKER_WALLET, "Maker Wallet");
        vm.label(FAKE_MAKER_WALLET, "Fake Maker Wallet");
        vm.label(TAKER_WALLET, "Taker Wallet");
        vm.label(FAKE_TAKER_WALLET, "Fake Taker Wallet");

        vm.label(address(tokenA), "TokenA");
        vm.label(address(tokenB), "TokenB");
    }
}
