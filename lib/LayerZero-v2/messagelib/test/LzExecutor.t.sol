// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { BytesLib } from "solidity-bytes-utils/contracts/BytesLib.sol";

import { ILayerZeroReceiver } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroReceiver.sol";
import { ILayerZeroEndpointV2, ExecutionState, Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Packet } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import { PacketV1Codec } from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/PacketV1Codec.sol";

import { ReceiveUln302 } from "../contracts/uln/uln302/ReceiveUln302.sol";
import { VerificationState } from "../contracts/uln/ReceiveUlnBase.sol";
import { LzExecutor, LzReceiveParam, NativeDropParam } from "../contracts/uln/LzExecutor.sol";

import { Setup } from "./util/Setup.sol";
import { PacketUtil } from "./util/Packet.sol";
import { Constant } from "./util/Constant.sol";
import "forge-std/console.sol";

contract LzExecutorTest is Test, ILayerZeroReceiver {
    Setup.FixtureV2 internal fixtureV2;
    ReceiveUln302 internal receiveUln302;
    ILayerZeroEndpointV2 internal endpointV2;
    LzExecutor internal lzExecutor;
    uint32 internal EID;

    Origin origin;
    Packet packet;
    bytes packetHeader;
    bytes32 payloadHash;
    address receiver;

    address alice = address(0x1234);

    function setUp() public {
        fixtureV2 = Setup.loadFixtureV2(Constant.EID_ETHEREUM);
        endpointV2 = ILayerZeroEndpointV2(fixtureV2.endpointV2);
        receiveUln302 = fixtureV2.receiveUln302;
        lzExecutor = new LzExecutor(address(fixtureV2.receiveUln302), address(fixtureV2.endpointV2));
        EID = fixtureV2.eid;

        // wire to self
        Setup.wireFixtureV2WithRemote(fixtureV2, fixtureV2.eid);

        // setup packet
        origin = Origin(EID, bytes32(uint256(uint160(address(this)))), 1);
        receiver = address(this);
        packet = PacketUtil.newPacket(1, EID, address(this), EID, receiver, abi.encodePacked("message"));
        origin = Origin(packet.srcEid, bytes32(uint256(uint160(packet.sender))), packet.nonce);
        bytes memory encodedPacket = PacketV1Codec.encode(packet);
        packetHeader = BytesLib.slice(encodedPacket, 0, 81);
        payloadHash = keccak256(BytesLib.slice(encodedPacket, 81, encodedPacket.length - 81));

        origin = Origin(EID, bytes32(uint256(uint160(address(this)))), 1);
        receiver = address(this);
    }

    function test_CommitAndExecute_OnlyExecute() public {
        // verify
        vm.prank(address(fixtureV2.dvn));
        receiveUln302.verify(packetHeader, payloadHash, 1);
        receiveUln302.commitVerification(packetHeader, payloadHash);

        // verified
        assertEq(uint256(receiveUln302.verifiable(packetHeader, payloadHash)), uint256(VerificationState.Verified));
        // executable
        assertEq(uint256(endpointV2.executable(origin, receiver)), uint256(ExecutionState.Executable));

        // commit and execute
        lzExecutor.commitAndExecute(
            address(receiveUln302),
            LzReceiveParam(origin, receiver, packet.guid, packet.message, "", 100000, 0),
            NativeDropParam(address(0x0), 0)
        );

        // executed
        assertEq(uint256(endpointV2.executable(origin, receiver)), uint256(ExecutionState.Executed));
    }

    function test_CommitAndExecute_NativeDropAndExecute() public {
        // verify
        vm.prank(address(fixtureV2.dvn));
        receiveUln302.verify(packetHeader, payloadHash, 1);
        receiveUln302.commitVerification(packetHeader, payloadHash);

        vm.deal(address(this), 1000);
        assertEq(alice.balance, 0); // alice had no funds
        // commit and execute
        lzExecutor.commitAndExecute{ value: 1000 }(
            address(receiveUln302),
            LzReceiveParam(origin, receiver, packet.guid, packet.message, "", 100000, 0),
            NativeDropParam(alice, 1000)
        );
        assertEq(address(this).balance, 0);
        assertEq(address(lzExecutor).balance, 0);
        assertEq(alice.balance, 1000); // alice received funds

        // executed
        assertEq(uint256(endpointV2.executable(origin, receiver)), uint256(ExecutionState.Executed));
    }

    function test_CommitAndExecute_ExecuteWithValue() public {
        // verify
        vm.prank(address(fixtureV2.dvn));
        receiveUln302.verify(packetHeader, payloadHash, 1);
        receiveUln302.commitVerification(packetHeader, payloadHash);

        vm.deal(address(this), 1000);
        // commit and execute
        lzExecutor.commitAndExecute{ value: 1000 }(
            address(receiveUln302),
            LzReceiveParam(origin, receiver, packet.guid, packet.message, "", 100000, 1000),
            NativeDropParam(address(0x0), 0)
        );
        assertEq(address(lzExecutor).balance, 0);
        assertEq(address(this).balance, 1000);

        // executed
        assertEq(uint256(endpointV2.executable(origin, receiver)), uint256(ExecutionState.Executed));
    }

    function test_CommitAndExecute_VerifyAndExecute() public {
        // verifiable
        vm.prank(address(fixtureV2.dvn));
        receiveUln302.verify(packetHeader, payloadHash, 1);

        // verifiable
        assertEq(uint256(receiveUln302.verifiable(packetHeader, payloadHash)), uint256(VerificationState.Verifiable));
        // not executable
        assertEq(uint256(endpointV2.executable(origin, receiver)), uint256(ExecutionState.NotExecutable));

        // commit and execute
        lzExecutor.commitAndExecute(
            address(receiveUln302),
            LzReceiveParam(origin, receiver, packet.guid, packet.message, "", 100000, 0),
            NativeDropParam(address(0x0), 0)
        );

        // verified
        assertEq(uint256(receiveUln302.verifiable(packetHeader, payloadHash)), uint256(VerificationState.Verified));
        // executed
        assertEq(uint256(endpointV2.executable(origin, receiver)), uint256(ExecutionState.Executed));
    }

    function test_CommitAndExecute_Revert_Verifying() public {
        assertEq(uint256(receiveUln302.verifiable(packetHeader, payloadHash)), uint256(VerificationState.Verifying));

        vm.expectRevert(LzExecutor.Verifying.selector);
        lzExecutor.commitAndExecute(
            address(receiveUln302),
            LzReceiveParam(origin, receiver, packet.guid, packet.message, "", 100000, 0),
            NativeDropParam(address(0x0), 0)
        );
    }

    function test_CommitAndExecute_Revert_Executed() public {
        vm.prank(address(fixtureV2.dvn));
        receiveUln302.verify(packetHeader, payloadHash, 1);
        lzExecutor.commitAndExecute(
            address(receiveUln302),
            LzReceiveParam(origin, receiver, packet.guid, packet.message, "", 100000, 0),
            NativeDropParam(address(0x0), 0)
        );

        // try again
        vm.expectRevert(LzExecutor.Executed.selector);
        lzExecutor.commitAndExecute(
            address(receiveUln302),
            LzReceiveParam(origin, receiver, packet.guid, packet.message, "", 100000, 0),
            NativeDropParam(address(0x0), 0)
        );
    }

    function test_WithdrawNative() public {
        vm.deal(address(lzExecutor), 1000);
        assertEq(address(lzExecutor).balance, 1000);
        assertEq(alice.balance, 0);

        lzExecutor.withdrawNative(address(0x1234), 1000);
        assertEq(address(lzExecutor).balance, 0);
        assertEq(alice.balance, 1000);
    }

    function test_WithdrawNative_Revert_OnlyOwner() public {
        vm.deal(address(lzExecutor), 1000);
        assertEq(address(lzExecutor).balance, 1000);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        lzExecutor.withdrawNative(alice, 1000);
    }

    // implement ILayerZeroReceiver
    function allowInitializePath(Origin calldata) external pure override returns (bool) {
        return true;
    }

    function nextNonce(uint32, bytes32) external pure override returns (uint64) {
        return 0;
    }

    function lzReceive(Origin calldata, bytes32, bytes calldata, address, bytes calldata) external payable override {
        // do nothing
    }
}
