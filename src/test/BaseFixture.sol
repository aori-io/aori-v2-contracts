// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {SimpleToken} from "./mocks/SimpleToken.sol";
import {SimpleHook} from "./mocks/hooks/SimpleHook.sol";
import {RevertingHook} from "./mocks/hooks/RevertingHook.sol";
import {FailingHook} from "./mocks/hooks/FailingHook.sol";
import {TrickFailingHook} from "./mocks/hooks/TrickFailingHook.sol";
import {UnauthedHook} from "./mocks/hooks/UnauthedHook.sol";
import {SimpleFlashLoanReceiver} from "./mocks/flashloan/SimpleFlashLoanReceiver.sol";
import {RevertingFlashLoanReceiver} from "./mocks/flashloan/RevertingFlashLoanReceiver.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {AoriV2} from "../AoriV2.sol";
import {IAoriV2} from "../interfaces/IAoriV2.sol";

interface IERC20Mintable is IERC20 {
    function mint(uint256 amount) external;
}

contract BaseFixture is DSTest {
    /*//////////////////////////////////////////////////////////////
                             TEST UTILITIES
    //////////////////////////////////////////////////////////////*/

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/

    IAoriV2 internal aori;
    // Hooks
    SimpleHook internal simpleHook;
    RevertingHook internal revertHook;
    FailingHook internal failingHook;
    TrickFailingHook internal trickFailingHook;
    UnauthedHook internal unauthedHook;

    // Loan Receivers
    SimpleFlashLoanReceiver internal flashloanReceiver;
    RevertingFlashLoanReceiver internal revertFlashloanReceiver;

    /*//////////////////////////////////////////////////////////////
                                 USERS
    //////////////////////////////////////////////////////////////*/

    uint256 FAKE_ORDER_PROTOCOL_KEY = 69;
    uint256 SERVER_PRIVATE_KEY = 1;
    uint256 FAKE_SERVER_PRIVATE_KEY = 2;
    uint256 MAKER_PRIVATE_KEY = 3;
    uint256 FAKE_MAKER_PRIVATE_KEY = 4;
    uint256 TAKER_PRIVATE_KEY = 5;
    uint256 FAKE_TAKER_PRIVATE_KEY = 6;
    uint256 SEARCHER_PRIVATE_KEY = 7;

    address SERVER_WALLET;
    address FAKE_SERVER_WALLET;
    address MAKER_WALLET;
    address FAKE_MAKER_WALLET;
    address TAKER_WALLET;
    address FAKE_TAKER_WALLET;
    address SEARCHER_WALLET;

    SimpleToken internal tokenA = new SimpleToken();
    SimpleToken internal tokenB = new SimpleToken();

    function setUp() public virtual {
        utils = new Utilities();
        users = utils.createUsers(5);

        SERVER_WALLET = address(vm.addr(SERVER_PRIVATE_KEY));
        FAKE_SERVER_WALLET = address(vm.addr(FAKE_SERVER_PRIVATE_KEY));
        MAKER_WALLET = address(vm.addr(MAKER_PRIVATE_KEY));
        FAKE_MAKER_WALLET = address(vm.addr(FAKE_MAKER_PRIVATE_KEY));
        TAKER_WALLET = address(vm.addr(TAKER_PRIVATE_KEY));
        FAKE_TAKER_WALLET = address(vm.addr(FAKE_TAKER_PRIVATE_KEY));
        SEARCHER_WALLET = address(vm.addr(SEARCHER_PRIVATE_KEY));

        aori = new AoriV2(SERVER_WALLET);

        // Setup hook contracts
        simpleHook = new SimpleHook();
        revertHook = new RevertingHook();
        failingHook = new FailingHook();
        trickFailingHook = new TrickFailingHook();
        unauthedHook = new UnauthedHook();

        // Setup flashloan receiver
        flashloanReceiver = new SimpleFlashLoanReceiver();
        revertFlashloanReceiver = new RevertingFlashLoanReceiver();

        vm.label(address(aori), "AoriV2");
        vm.label(address(flashloanReceiver), "FlashloanReceiver");
        vm.label(address(revertFlashloanReceiver), "RevertFlashloanReceiver");

        vm.label(SERVER_WALLET, "Server Wallet");
        vm.label(FAKE_SERVER_WALLET, "Fake Server Wallet");
        vm.label(MAKER_WALLET, "Maker Wallet");
        vm.label(FAKE_MAKER_WALLET, "Fake Maker Wallet");
        vm.label(TAKER_WALLET, "Taker Wallet");
        vm.label(FAKE_TAKER_WALLET, "Fake Taker Wallet");

        vm.label(address(tokenA), "TokenA");
        vm.label(address(tokenB), "TokenB");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _generateBaseOrder(
        address offerer,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 outputAmount
    ) public view returns (IAoriV2.Order memory) {
        return
            IAoriV2.Order({
                offerer: offerer,
                inputToken: inputToken,
                inputAmount: inputAmount,
                inputZone: address(aori),
                outputToken: outputToken,
                outputAmount: outputAmount,
                outputZone: address(aori),
                startTime: block.timestamp,
                endTime: block.timestamp + 1000,
                salt: 0,
                counter: 0,
                inputChainId: block.chainid,
                outputChainId: block.chainid,
                toWithdraw: false
            });
    }

    function _signOrder(
        uint256 privateKey,
        IAoriV2.Order memory order
    ) public view returns (uint8 v, bytes32 r, bytes32 s) {
        (v, r, s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    aori.getOrderHash(order)
                )
            )
        );
    }

    function _generateBaseMatching(
        IAoriV2.Order memory makerOrder,
        IAoriV2.Order memory takerOrder
    ) public view returns (IAoriV2.MatchingDetails memory) {
        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(
            MAKER_PRIVATE_KEY,
            makerOrder
        );
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(
            TAKER_PRIVATE_KEY,
            takerOrder
        );

        return
            IAoriV2.MatchingDetails({
                makerOrder: makerOrder,
                takerOrder: takerOrder,
                makerSignature: abi.encodePacked(makerR, makerS, makerV),
                takerSignature: abi.encodePacked(takerR, takerS, takerV),
                blockDeadline: block.number + 100,
                feeTag: "aori",
                feeRecipient: SERVER_WALLET
            });
    }

    function _signMatching(
        uint256 privateKey,
        IAoriV2.MatchingDetails memory matching
    ) public view returns (uint8 v, bytes32 r, bytes32 s) {
        (v, r, s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    aori.getMatchingHash(matching)
                )
            )
        );
    }

    function _mintApproveAori(
        address _to,
        address _token,
        uint256 _amount
    ) public {
        vm.startPrank(_to);
        IERC20Mintable(_token).mint(_amount);
        IERC20(_token).approve(address(aori), _amount);
        vm.stopPrank();
    }

    function _mintApproveDepositAori(
        address _to,
        address _token,
        uint256 _amount
    ) public {
        vm.startPrank(_to);
        IERC20Mintable(_token).mint(_amount);
        IERC20(_token).approve(address(aori), _amount);
        aori.deposit(_to, _token, _amount);
        vm.stopPrank();
    }

    function _createBaseMatching(
        IAoriV2.Order memory makerOrder,
        IAoriV2.Order memory takerOrder,
        address seatHolder,
        uint256 seatPercentOfFees
    )
        public
        view
        returns (
            IAoriV2.MatchingDetails memory matching,
            uint8 serverV,
            bytes32 serverR,
            bytes32 serverS
        )
    {
        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(
            MAKER_PRIVATE_KEY,
            makerOrder
        );
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(
            TAKER_PRIVATE_KEY,
            takerOrder
        );

        matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            feeTag: "aori",
            feeRecipient: SERVER_WALLET
        });

        (serverV, serverR, serverS) = _signMatching(
            SERVER_PRIVATE_KEY,
            matching
        );
    }

    /*//////////////////////////////////////////////////////////////
                               SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    function _settleAoriOrders_expectRevertEmpty(
        IAoriV2.Order memory makerOrder,
        IAoriV2.Order memory takerOrder
    ) public {
        vm.startPrank(SERVER_WALLET);
        IAoriV2.MatchingDetails memory matching = _generateBaseMatching(
            makerOrder,
            takerOrder
        );
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(
            SERVER_PRIVATE_KEY,
            matching
        );
        vm.expectRevert();
        aori.settleOrders(
            matching,
            abi.encodePacked(serverR, serverS, serverV),
            ""
        );
        vm.stopPrank();
    }

    function _settleAoriOrders_expectRevert(
        IAoriV2.Order memory makerOrder,
        IAoriV2.Order memory takerOrder,
        bytes memory revertData
    ) public {
        vm.startPrank(SERVER_WALLET);
        IAoriV2.MatchingDetails memory matching = _generateBaseMatching(
            makerOrder,
            takerOrder
        );
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(
            SERVER_PRIVATE_KEY,
            matching
        );
        vm.expectRevert(revertData);
        aori.settleOrders(
            matching,
            abi.encodePacked(serverR, serverS, serverV),
            ""
        );
        vm.stopPrank();
    }

    function _settleAoriOrders_successful(
        IAoriV2.Order memory makerOrder,
        IAoriV2.Order memory takerOrder
    ) public {
        vm.startPrank(SERVER_WALLET);
        IAoriV2.MatchingDetails memory matching = _generateBaseMatching(
            makerOrder,
            takerOrder
        );
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(
            SERVER_PRIVATE_KEY,
            matching
        );
        aori.settleOrders(
            matching,
            abi.encodePacked(serverR, serverS, serverV),
            ""
        );
        vm.stopPrank();
    }

    function _settleAoriOrders_successfulCustomSettler(
        address settler,
        IAoriV2.Order memory makerOrder,
        IAoriV2.Order memory takerOrder
    ) public {
        IAoriV2.MatchingDetails memory matching = _generateBaseMatching(
            makerOrder,
            takerOrder
        );
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(
            SERVER_PRIVATE_KEY,
            matching
        );
        vm.startPrank(settler);
        aori.settleOrders(
            matching,
            abi.encodePacked(serverR, serverS, serverV),
            ""
        );
        vm.stopPrank();
    }

    function _settleAoriMatching_expectRevert(
        IAoriV2.MatchingDetails memory matching,
        bytes memory revertData
    ) public {
        vm.startPrank(SERVER_WALLET);
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(
            SERVER_PRIVATE_KEY,
            matching
        );
        vm.expectRevert(revertData);
        aori.settleOrders(
            matching,
            abi.encodePacked(serverR, serverS, serverV),
            ""
        );
        vm.stopPrank();
    }

    function _settleAoriMatchingWithSignature_expectRevert(
        IAoriV2.MatchingDetails memory matching,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes memory revertData
    ) public {
        vm.startPrank(SERVER_WALLET);
        vm.expectRevert(revertData);
        aori.settleOrders(matching, abi.encodePacked(r, s, v), "");
        vm.stopPrank();
    }

    function _incrementCounter(address _to) public {
        vm.prank(_to);
        aori.incrementCounter();
    }
}
