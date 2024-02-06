// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {SimpleToken} from "./mocks/SimpleToken.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import { AoriV2 } from "../AoriV2.sol";
import { BaseFixture } from "./BaseFixture.sol";
import { IAoriV2 } from "../interfaces/IAoriV2.sol";

interface IERC20Mintable is IERC20 {
    function mint(uint256 amount) external;
}

contract AoriV2Test is BaseFixture {

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testDeposit_failNoApproval() public {
        uint256 amount = 100;
        vm.startPrank(MAKER_WALLET);
        tokenA.mint(amount);
        vm.expectRevert();
        aori.deposit(MAKER_WALLET, address(tokenA), amount);
        vm.stopPrank();
    }
    function testDeposit_failNoBalance() public {
        uint256 amount = 100;
        vm.startPrank(MAKER_WALLET);
        vm.expectRevert();
        aori.deposit(MAKER_WALLET, address(tokenA), amount);
        vm.stopPrank();
    }

    function testDeposit_success() public {
        assert(aori.balanceOf(MAKER_WALLET, address(tokenA)) == 0);
        uint256 amount = 100;
        vm.startPrank(MAKER_WALLET);
        tokenA.mint(amount);
        tokenA.approve(address(aori), amount);
        aori.deposit(MAKER_WALLET, address(tokenA), amount);
        vm.stopPrank();
        assert(aori.balanceOf(MAKER_WALLET, address(tokenA)) == amount);
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testWithdraw_failNoBalance() public {
        uint256 amount = 100;
        vm.startPrank(MAKER_WALLET);
        vm.expectRevert();
        aori.withdraw(address(tokenA), amount);
        vm.stopPrank();
    }

    function testWithdraw_failDepositThenWithdrawMore() public {
        uint256 amount = 100;
        vm.startPrank(MAKER_WALLET);
        tokenA.mint(amount);
        tokenA.approve(address(aori), amount);
        aori.deposit(MAKER_WALLET, address(tokenA), amount - 1);
        vm.expectRevert();
        aori.withdraw(address(tokenA), amount);
        vm.stopPrank();
    }

    function testWithdraw_success() public {
        uint256 amount = 100;
        vm.startPrank(MAKER_WALLET);
        tokenA.mint(amount);
        tokenA.approve(address(aori), amount);
        aori.deposit(MAKER_WALLET, address(tokenA), amount);
        assert(aori.balanceOf(MAKER_WALLET, address(tokenA)) == amount);
        aori.withdraw(address(tokenA), amount);
        vm.stopPrank();
        assert(aori.balanceOf(MAKER_WALLET, address(tokenA)) == 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SETTLEORDER
    //////////////////////////////////////////////////////////////*/

    function testSettleOrders_failMakerStartTimeInFuture() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Order Edits
        makerOrder.startTime = block.timestamp + 10000;
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Maker order start time is in the future");
    }

    function testSettleOrders_failTakerStartTimeInFuture() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Order Edits
        takerOrder.startTime = block.timestamp + 10000;
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Taker order start time is in the future");
    }

    function testSettleOrders_failMakerEndTimeAlreadySurpassed() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Order Edits
        makerOrder.endTime = block.timestamp - 100;
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Maker order end time has already passed");
    }

    function testSettleOrders_failTakerEndTimeAlreadySurpassed() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Order Edits
        takerOrder.endTime = block.timestamp - 100;
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Taker order end time has already passed");
    }

    function testSettleOrders_failMakerCounterTooOld() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        _incrementCounter(MAKER_WALLET);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Counter of maker order is too low");
    }

    function testSettleOrders_failTakerCounterTooOld() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        _incrementCounter(TAKER_WALLET);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Counter of taker order is too low");
    }

    function testSettleOrders_failMakerInputChainIdIsNotCorrect() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Order Edits
        makerOrder.inputChainId = block.chainid + 1;
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Maker order's input chainid does not match taker order's output chainid");
    }

    function testSettleOrders_failTakerInputChainIdIsNotCorrect() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Order Edits
        takerOrder.inputChainId = block.chainid + 1;
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Taker order's input chainid does not match maker order's output chainid");
    }

    function testSettleOrders_failMakerZoneIsNotCorrect() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Order Edits
        makerOrder.inputZone = address(0x0);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Maker order's input zone does not match taker order's output zone");
    }

    function testSettleOrders_failTakerZoneIsNotCorrect() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Order Edits
        takerOrder.inputZone = address(0x0);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Taker order's input zone does not match maker order's output zone");
    }

    function testSettleOrders_failMakerSignatureDoesNotCorrespondToOrderDetails() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(FAKE_MAKER_PRIVATE_KEY, makerOrder);
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(TAKER_PRIVATE_KEY, takerOrder);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        /// Settle
        IAoriV2.MatchingDetails memory matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            seatNumber: 0,
            seatHolder: TAKER_WALLET,
            seatPercentOfFees: 0
        });
        _settleAoriMatching_expectRevert(matching, "Maker signature does not correspond to order details");
    }

    function testSettleOrders_failTakerSignatureDoesNotCorrespondToOrderDetails() public {
         /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(MAKER_PRIVATE_KEY, makerOrder);
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(FAKE_TAKER_PRIVATE_KEY, takerOrder);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        /// Settle
        IAoriV2.MatchingDetails memory matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            seatNumber: 0,
            seatHolder: TAKER_WALLET,
            seatPercentOfFees: 0
        });
        _settleAoriMatching_expectRevert(matching, "Taker signature does not correspond to order details");
    }

    function testSettleOrders_failTakerOutputAmountLessThanMakerInputAmount() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 101);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Taker order output amount is more than maker order input amount");
    }

    function testSettleOrders_failMakerOutputAmountLessThanTakerInputAmount() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 101);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Maker order output amount is more than taker order input amount");
    }

    function testSettleOrders_failMakerHashHasAlreadyBeenSettled() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_successful(makerOrder, takerOrder);

        /// Create Orders
        makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 99);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Maker order has been settled");
    }

    function testSettleOrders_failTakerHashHasAlreadyBeenSettled() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_successful(makerOrder, takerOrder);

        /// Create Orders
        makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 99);
        takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);
        /// Settle
        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Taker order has been settled");
    }

    function testSettleOrders_failBlockDeadlineHasPassed() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        /// Settle
        (IAoriV2.MatchingDetails memory matching,,,) = _createBaseMatching(makerOrder, takerOrder, TAKER_WALLET, 0);
        matching.blockDeadline = block.number - 1;
        _settleAoriMatching_expectRevert(matching, "Order execution deadline has passed");
    }

    function testSettleOrders_failServerSignatureDoesNotCorrespondToOrderDetailsByMakerOrder() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(MAKER_PRIVATE_KEY, makerOrder);
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(TAKER_PRIVATE_KEY, takerOrder);

        /// Order Edits
        makerOrder.inputAmount = 99;

        /// Settle
        IAoriV2.MatchingDetails memory matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            seatNumber: 0,
            seatHolder: TAKER_WALLET,
            seatPercentOfFees: 0
        });
        _settleAoriMatching_expectRevert(matching, "Maker signature does not correspond to order details");
    }

    function testSettleOrders_failServerSignatureDoesNotCorrespondToOrderDetailsByTakerOrder() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(MAKER_PRIVATE_KEY, makerOrder);
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(TAKER_PRIVATE_KEY, takerOrder);

        /// Order Edits
        takerOrder.inputAmount = 99;

        /// Settle
        IAoriV2.MatchingDetails memory matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            seatNumber: 0,
            seatHolder: TAKER_WALLET,
            seatPercentOfFees: 0
        });
        _settleAoriMatching_expectRevert(matching, "Taker signature does not correspond to order details");
    }

    function testSettleOrders_failServerSignatureDoesNotCorrespondToOrderDetailsByBlockDeadline() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(MAKER_PRIVATE_KEY, makerOrder);
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(TAKER_PRIVATE_KEY, takerOrder);

        IAoriV2.MatchingDetails memory matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            seatNumber: 0,
            seatHolder: TAKER_WALLET,
            seatPercentOfFees: 0
        });
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(SERVER_PRIVATE_KEY, matching);

        /// Settle
        matching.blockDeadline = block.number + 5;
        _settleAoriMatchingWithSignature_expectRevert(matching, serverV, serverR, serverS, "Server signature does not correspond to order details");
    }

    function testSettleOrders_failServerSignatureDoesNotCorrespondToOrderDetailsBySeatNumber() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);


        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(MAKER_PRIVATE_KEY, makerOrder);
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(TAKER_PRIVATE_KEY, takerOrder);

        IAoriV2.MatchingDetails memory matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            seatNumber: 0,
            seatHolder: TAKER_WALLET,
            seatPercentOfFees: 0
        });
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(SERVER_PRIVATE_KEY, matching);

        // Edits
        matching.seatNumber = 1;
        _settleAoriMatchingWithSignature_expectRevert(matching, serverV, serverR, serverS, "Server signature does not correspond to order details");
    }

    function testSettleOrders_failServerSignatureDoesNotCorrespondToOrderDetailsBySeatHolder() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(MAKER_PRIVATE_KEY, makerOrder);
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(TAKER_PRIVATE_KEY, takerOrder);

        IAoriV2.MatchingDetails memory matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            seatNumber: 0,
            seatHolder: TAKER_WALLET,
            seatPercentOfFees: 0
        });
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(SERVER_PRIVATE_KEY, matching);

        // Edits
        matching.seatHolder = FAKE_TAKER_WALLET;
        _settleAoriMatchingWithSignature_expectRevert(matching, serverV, serverR, serverS, "Server signature does not correspond to order details");
    }

    function testSettleOrders_failServerSignatureDoesNotCorrespondToOrderDetailsBySeatPercentOfFees() public {
        /// Create Orders
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        /// Prepare
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        (uint8 makerV, bytes32 makerR, bytes32 makerS) = _signOrder(MAKER_PRIVATE_KEY, makerOrder);
        (uint8 takerV, bytes32 takerR, bytes32 takerS) = _signOrder(TAKER_PRIVATE_KEY, takerOrder);

        IAoriV2.MatchingDetails memory matching = IAoriV2.MatchingDetails({
            makerOrder: makerOrder,
            takerOrder: takerOrder,
            makerSignature: abi.encodePacked(makerR, makerS, makerV),
            takerSignature: abi.encodePacked(takerR, takerS, takerV),
            blockDeadline: block.number + 100,
            seatNumber: 0,
            seatHolder: TAKER_WALLET,
            seatPercentOfFees: 0
        });
        (uint8 serverV, bytes32 serverR, bytes32 serverS) = _signMatching(SERVER_PRIVATE_KEY, matching);

        // Edits
        matching.seatPercentOfFees = 5;
        _settleAoriMatchingWithSignature_expectRevert(matching, serverV, serverR, serverS, "Server signature does not correspond to order details");
    }

    function testSettleOrder_successSimpleInternalSwap() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_successful(makerOrder, takerOrder);
    }

    function testSettleOrder_successSimpleTakerInternalSwap() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        makerOrder.toWithdraw = true;

        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_successful(makerOrder, takerOrder);
    }

    function testSettleOrder_successSimpleMakerInternalSwap() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        takerOrder.toWithdraw = true;

        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_successful(makerOrder, takerOrder);
    }

    function testSettleOrder_successSimpleExternalSwap() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(MAKER_WALLET, address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);
        makerOrder.toWithdraw = true;
        takerOrder.toWithdraw = true;

        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_successful(makerOrder, takerOrder);
    }

    function testSettleOrder_successComplexTakerInternalSwap_A() public {}
    function testSettleOrder_successComplexTakerExternalSwap_A() public {}

    function testSettleOrder_successComplexTakerInternalSwap_B() public {}
    function testSettleOrder_successComplexTakerExternalSwap_B() public {}

    function testSettleOrder_successComplexTakerInternalSwap_C() public {}
    function testSettleOrder_successComplexTakerExternalSwap_C() public {}

    function testSettleOrder_successComplexTakerInternalSwap_D() public {}
    function testSettleOrder_successComplexTakerExternalSwap_D() public {}

    function testSettleOrder_successComplexTakerInternalSwap_E() public {}
    function testSettleOrder_successComplexTakerExternalSwap_E() public {}

    /*//////////////////////////////////////////////////////////////
                                 HOOKS
    //////////////////////////////////////////////////////////////*/

    function testSettleOrder_successSimpleExternalSwapWithSimpleHook() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(address(simpleHook), address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        _mintApproveAori(address(simpleHook), address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_successful(makerOrder, takerOrder);
        assert(aori.balanceOf(address(simpleHook), address(tokenB)) == 100);
    }

    function testSettleOrder_failSimpleExternalSwapWithFailingHook() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(address(failingHook), address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        _mintApproveAori(address(failingHook), address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "BeforeAoriTrade hook failed");
    }

    function testSettleOrder_failSimpleExternalSwapWithTrickFailingHook() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(address(trickFailingHook), address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        _mintApproveAori(address(trickFailingHook), address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "AfterAoriTrade hook failed");
    }

    function testSettleOrder_successSimpleExternalSwapWithRevertingHook() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(address(revertHook), address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        _mintApproveAori(address(revertHook), address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_expectRevertEmpty(makerOrder, takerOrder);
    }

    function testSettleOrder_failSimpleExternalSwapWithUnauthedHook() public {
        IAoriV2.Order memory makerOrder = _generateBaseOrder(address(unauthedHook), address(tokenA), 100, address(tokenB), 100);
        IAoriV2.Order memory takerOrder = _generateBaseOrder(TAKER_WALLET, address(tokenB), 100, address(tokenA), 100);

        _mintApproveAori(address(unauthedHook), address(tokenA), 1 ether);
        _mintApproveDepositAori(TAKER_WALLET, address(tokenB), 1 ether);

        _settleAoriOrders_expectRevert(makerOrder, takerOrder, "Maker signature does not correspond to order details");
    }

    /*//////////////////////////////////////////////////////////////
                               FLASH LOAN
    //////////////////////////////////////////////////////////////*/

    function testFlashLoan_failNoLiquidityForReceive() public {
        vm.startPrank(MAKER_WALLET);
        vm.expectRevert();
        aori.flashLoan(MAKER_WALLET, address(tokenA), 100, "", true);
        vm.stopPrank();
    }
    function testFlashLoan_failReceiveFlashLoanReverts() public {
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);   
        vm.startPrank(MAKER_WALLET);
        vm.expectRevert();
        aori.flashLoan(address(revertFlashloanReceiver), address(tokenA), 100, "", true);
        vm.stopPrank();
    }

    function testFlashLoan_failRemovesApproval() public {
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        vm.startPrank(MAKER_WALLET);
        vm.expectRevert();
        aori.flashLoan(address(flashloanReceiver), address(tokenA), 100, "", true);
        vm.stopPrank();
    }
    function testFlashLoan_successZeroLiquidity() public {
        vm.startPrank(MAKER_WALLET);
        aori.flashLoan(address(flashloanReceiver), address(tokenA), 0, "", true);
        vm.stopPrank();
    }
    function testFlashLoan_successNoActionsReceive() public {
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        vm.prank(address(flashloanReceiver));
        IERC20(address(tokenA)).approve(address(aori), 1 ether);
        vm.startPrank(MAKER_WALLET);
        assert(aori.balanceOf(address(flashloanReceiver), address(tokenA)) == 0);
        aori.flashLoan(address(flashloanReceiver), address(tokenA), 100, "", true);
        assert(aori.balanceOf(address(flashloanReceiver), address(tokenA)) == 0);
        vm.stopPrank();
    }

    function testFlashLoan_successNoActionsNoReceive() public {
        _mintApproveDepositAori(MAKER_WALLET, address(tokenA), 1 ether);
        vm.prank(address(flashloanReceiver));
        IERC20(address(tokenA)).approve(address(aori), 1 ether);
        vm.startPrank(MAKER_WALLET);
        assert(aori.balanceOf(address(flashloanReceiver), address(tokenA)) == 0);
        aori.flashLoan(address(flashloanReceiver), address(tokenA), 100, "", false);
        assert(aori.balanceOf(address(flashloanReceiver), address(tokenA)) == 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             INCREMENTNONCE
    //////////////////////////////////////////////////////////////*/

    function testIncrementCounter_success() public {
        vm.startPrank(MAKER_WALLET);
        assert(aori.getCounter() == 0);
        uint256 counter = aori.getCounter();
        aori.incrementCounter();
        assertEq(aori.getCounter(), counter + 1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SETTAKERFEE
    //////////////////////////////////////////////////////////////*/

    function testSetTakerFee_failNotOwner() public {
        vm.startPrank(FAKE_SERVER_WALLET);
        vm.expectRevert("Taker fee address must be server signer");
        aori.setTakerFee(100, FAKE_SERVER_WALLET);
        vm.stopPrank();
    }

    function testSetTakerFee_failBipsMoreThan100() public {
        vm.startPrank(SERVER_WALLET);
        vm.expectRevert("Taker fee bips must be less than 1%");
        aori.setTakerFee(101, TAKER_WALLET);
        vm.stopPrank();
    }

    function testSetTakerFee_success() public {
        vm.startPrank(SERVER_WALLET);
        aori.setTakerFee(100, TAKER_WALLET);
        vm.stopPrank();
    }
}
