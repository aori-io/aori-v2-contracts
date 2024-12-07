pragma solidity 0.8.24;

import {AoriV2} from "../contracts/AoriV2.sol";
import {MockSimpleMatch} from "./mocks/zones/MockSimpleMatch.sol";
import {BaseFixture} from "./BaseFixture.sol";
import {ClearingUtils} from "../contracts/libs/ClearingUtils.sol";
import {OnlyReleaseZone} from "./mocks/zones/OnlyReleaseZone.sol";
import {IClearing} from "../contracts/interfaces/IClearing.sol";

contract AoriV2Test is BaseFixture {
    function setUp() public override {
        clearingInstance = address(new AoriV2());
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    function testSettle_failRevertingZone() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(revertingZone),
                ""
            )
        );
        vm.expectRevert();
        _settle(MAKER_PRIVATE_KEY, orders, "");
    }

    function testSettle_successZeroOrders() public {
        _settle(MAKER_PRIVATE_KEY, orders, "");
    }

    function testSettle_failOrdersNotForChain() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        vm.chainId(block.chainid + 1);

        vm.expectRevert();
        _settle(MAKER_PRIVATE_KEY, orders, "");
    }

    function testSettle_failOrdersNotForSameZone() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(revertingZone),
                ""
            )
        );

        vm.expectRevert();
        _settle(MAKER_PRIVATE_KEY, orders, "");
    }

    function testSettle_failNonUniqueOrdersWithNoopZone() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(noopZone),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(noopZone),
                ""
            )
        );

        vm.expectRevert();
        _settle(MAKER_PRIVATE_KEY, orders, "");
    }

    function testSettle_failNonUniqueOrdersWithSimpleMatch() public {
        // Settle orders
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        vm.expectRevert();
        _settle(MAKER_PRIVATE_KEY, orders, "");
        // assert(_hasSettled(ClearingUtils.getOrderHash(orders[0].order)));
    }

    function testSettle_failNotApproved() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );
    }

    function testSettle_successOnlyReleaseZone() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(onlyReleaseZone),
                ""
            )
        );

        _settle(MAKER_PRIVATE_KEY, orders, "");
        assert(
            _hasSettled(
                orders[0].order.offerer,
                ClearingUtils.getOrderHash(orders[0].order)
            )
        );
    }

    function testSettle_successMatchingFromEOAs() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                100,
                address(tokenB),
                100,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                TAKER_PRIVATE_KEY,
                address(tokenB),
                100,
                address(tokenA),
                100,
                TAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        _mintAndApprove(MAKER_WALLET, address(tokenA), 200);
        _mintAndApprove(TAKER_WALLET, address(tokenB), 200);

        _settle(MAKER_PRIVATE_KEY, orders, "");
        assert(
            _hasSettled(
                orders[0].order.offerer,
                ClearingUtils.getOrderHash(orders[0].order)
            )
        );
        assert(
            _hasSettled(
                orders[1].order.offerer,
                ClearingUtils.getOrderHash(orders[1].order)
            )
        );
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 0);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenB)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenA)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenB)) == 0);
    }

    function testSettle_successMatchingFromDeposited() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                100,
                address(tokenB),
                100,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                TAKER_PRIVATE_KEY,
                address(tokenB),
                100,
                address(tokenA),
                100,
                TAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        _mintAndApprove(MAKER_WALLET, address(tokenA), 200);
        _deposit(MAKER_WALLET, address(tokenA), 150);
        _mintAndApprove(TAKER_WALLET, address(tokenB), 200);
        _deposit(TAKER_WALLET, address(tokenB), 150);

        _settle(MAKER_PRIVATE_KEY, orders, "");
        assert(
            _hasSettled(
                orders[0].order.offerer,
                ClearingUtils.getOrderHash(orders[0].order)
            )
        );
        assert(
            _hasSettled(
                orders[1].order.offerer,
                ClearingUtils.getOrderHash(orders[1].order)
            )
        );
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 50);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenB)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenA)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenB)) == 50);
    }

    function testSettle_failMatchingWithAllZeroZones() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                100,
                address(tokenB),
                100,
                MAKER_WALLET,
                address(0),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                TAKER_PRIVATE_KEY,
                address(tokenB),
                100,
                address(tokenA),
                100,
                TAKER_WALLET,
                address(0),
                ""
            )
        );

        _mintAndApprove(MAKER_WALLET, address(tokenA), 200);
        _deposit(MAKER_WALLET, address(tokenA), 150);
        _mintAndApprove(TAKER_WALLET, address(tokenB), 200);
        _deposit(TAKER_WALLET, address(tokenB), 150);

        vm.expectRevert();
        _settle(MAKER_PRIVATE_KEY, orders, "");
    }

    function testSettle_successMatchingWithZeroZone() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                100,
                address(tokenB),
                100,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                TAKER_PRIVATE_KEY,
                address(tokenB),
                100,
                address(tokenA),
                100,
                TAKER_WALLET,
                address(0),
                ""
            )
        );

        _mintAndApprove(MAKER_WALLET, address(tokenA), 200);
        _deposit(MAKER_WALLET, address(tokenA), 150);
        _mintAndApprove(TAKER_WALLET, address(tokenB), 200);
        _deposit(TAKER_WALLET, address(tokenB), 150);

        _settle(MAKER_PRIVATE_KEY, orders, "");
        assert(
            _hasSettled(
                orders[0].order.offerer,
                ClearingUtils.getOrderHash(orders[0].order)
            )
        );
        assert(
            _hasSettled(
                orders[1].order.offerer,
                ClearingUtils.getOrderHash(orders[1].order)
            )
        );
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 50);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenB)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenA)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenB)) == 50);
    }

    function testSettle_successMatchingWithV2AddressAsZone() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                100,
                address(tokenB),
                100,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                TAKER_PRIVATE_KEY,
                address(tokenB),
                100,
                address(tokenA),
                100,
                TAKER_WALLET,
                address(clearingInstance),
                ""
            )
        );

        _mintAndApprove(MAKER_WALLET, address(tokenA), 200);
        _deposit(MAKER_WALLET, address(tokenA), 150);
        _mintAndApprove(TAKER_WALLET, address(tokenB), 200);
        _deposit(TAKER_WALLET, address(tokenB), 150);

        _settle(MAKER_PRIVATE_KEY, orders, "");
        assert(
            _hasSettled(
                orders[0].order.offerer,
                ClearingUtils.getOrderHash(orders[0].order)
            )
        );
        assert(
            _hasSettled(
                orders[1].order.offerer,
                ClearingUtils.getOrderHash(orders[1].order)
            )
        );
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 50);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenB)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenA)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenB)) == 50);
    }

    function testSettle_successMatchingWithZoneOfClearing() public {
        orders.push(
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                100,
                address(tokenB),
                100,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );

        orders.push(
            _generateSignedOrder(
                TAKER_PRIVATE_KEY,
                address(tokenB),
                100,
                address(tokenA),
                100,
                TAKER_WALLET,
                address(clearingInstance),
                ""
            )
        );

        _mintAndApprove(MAKER_WALLET, address(tokenA), 200);
        _deposit(MAKER_WALLET, address(tokenA), 150);
        _mintAndApprove(TAKER_WALLET, address(tokenB), 200);
        _deposit(TAKER_WALLET, address(tokenB), 150);

        _settle(MAKER_PRIVATE_KEY, orders, "");
        assert(
            _hasSettled(
                orders[0].order.offerer,
                ClearingUtils.getOrderHash(orders[0].order)
            )
        );
        assert(
            _hasSettled(
                orders[1].order.offerer,
                ClearingUtils.getOrderHash(orders[1].order)
            )
        );
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 50);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenB)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenA)) == 100);
        assert(_depositedBalanceOf(TAKER_WALLET, address(tokenB)) == 50);
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testDeposit_failNoApproval() public {
        uint256 amount = 100;
        _mint(MAKER_WALLET, address(tokenA), amount);
        vm.expectRevert();
        _deposit(MAKER_WALLET, address(tokenA), amount);
    }
    function testDeposit_failNoBalance() public {
        uint256 amount = 100;
        _approve(MAKER_WALLET, address(tokenA), amount);
        vm.expectRevert();
        _deposit(MAKER_WALLET, address(tokenA), amount);
    }

    function testDeposit_success() public {
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 0);
        uint256 amount = 100;
        _mint(MAKER_WALLET, address(tokenA), amount);
        _approve(MAKER_WALLET, address(tokenA), amount);
        _deposit(MAKER_WALLET, address(tokenA), amount);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == amount);
    }

    function testDeposit_successMoreThanBalance() public {
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 0);
        uint256 amount = 100;
        _mint(MAKER_WALLET, address(tokenA), amount);
        _approve(MAKER_WALLET, address(tokenA), amount);
        _deposit(MAKER_WALLET, address(tokenA), amount + 250);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == amount);
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testWithdraw_failNoBalance() public {
        uint256 amount = 100;
        vm.expectRevert();
        _withdraw(MAKER_WALLET, address(tokenA), amount);
    }

    function testWithdraw_failDepositThenWithdrawMore() public {
        uint256 amount = 100;
        _mintAndApprove(MAKER_WALLET, address(tokenA), amount);
        _deposit(MAKER_WALLET, address(tokenA), amount - 1);
        vm.expectRevert();
        _withdraw(MAKER_WALLET, address(tokenA), amount);
    }

    function testWithdraw_success() public {
        uint256 amount = 100;
        _mintAndApprove(MAKER_WALLET, address(tokenA), amount);
        _deposit(MAKER_WALLET, address(tokenA), amount);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == amount);
        _withdraw(MAKER_WALLET, address(tokenA), amount);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 0);
    }

    /*//////////////////////////////////////////////////////////////
                               FLASH LOAN
    //////////////////////////////////////////////////////////////*/

    function testFlashLoan_failNoLiquidityForReceive() public {
        vm.startPrank(MAKER_WALLET);
        vm.expectRevert();
        _flashLoan(
            MAKER_WALLET,
            address(flashloanReceiver),
            address(tokenA),
            100,
            "",
            true
        );
    }

    function testFlashLoan_failReceiveFlashLoanReverts() public {
        _mintAndApprove(MAKER_WALLET, address(tokenA), 1 ether);
        _deposit(MAKER_WALLET, address(tokenA), 1 ether);
        vm.expectRevert();
        _flashLoan(
            MAKER_WALLET,
            address(revertFlashloanReceiver),
            address(tokenA),
            100,
            "",
            true
        );
    }

    function testFlashLoan_failRemovesApproval() public {
        _mintAndApprove(MAKER_WALLET, address(tokenA), 1 ether);
        _deposit(MAKER_WALLET, address(tokenA), 1 ether);
        vm.expectRevert();
        _flashLoan(
            MAKER_WALLET,
            address(flashloanReceiver),
            address(tokenA),
            100,
            "",
            true
        );
    }

    // function testFlashLoan_failFeeOnTransferToken() public {
    //     tokenA = new FeeOnTransferToken(10);
    //     _mintApproveDepositAoriV2(MAKER_WALLET, address(tokenA), 1 ether);

    //     vm.prank(address(flashloanReceiver));
    //     IERC20(address(tokenA)).approve(address(AoriV2), 1 ether);

    //     vm.startPrank(TAKER_WALLET);
    //     vm.expectRevert("Flash loan not repaid");
    //     AoriV2.flash(
    //         address(flashloanReceiver),
    //         address(tokenA),
    //         100,
    //         "",
    //         true
    //     );
    //     vm.stopPrank();
    // }

    function testFlashLoan_successZeroLiquidity() public {
        _flashLoan(
            MAKER_WALLET,
            address(flashloanReceiver),
            address(tokenA),
            0,
            "",
            true
        );
        vm.stopPrank();
    }
    function testFlashLoan_successNoActionsReceive() public {
        _approve(address(flashloanReceiver), address(tokenA), 1 ether);

        _mintAndApprove(MAKER_WALLET, address(tokenA), 1 ether);
        _deposit(MAKER_WALLET, address(tokenA), 1 ether);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 1 ether);
        assert(
            _depositedBalanceOf(address(flashloanReceiver), address(tokenA)) ==
                0
        );
        _flashLoan(
            MAKER_WALLET,
            address(flashloanReceiver),
            address(tokenA),
            100,
            "",
            true
        );
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 1 ether);
        assert(
            _depositedBalanceOf(address(flashloanReceiver), address(tokenA)) ==
                0
        );
    }

    function testFlashLoan_successNoActionsNoReceive() public {
        _mintAndApprove(MAKER_WALLET, address(tokenA), 1 ether);
        _deposit(MAKER_WALLET, address(tokenA), 1 ether);
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 1 ether);
        assert(
            _depositedBalanceOf(address(flashloanReceiver), address(tokenA)) ==
                0
        );
        _flashLoan(
            MAKER_WALLET,
            address(flashloanReceiver),
            address(tokenA),
            100,
            "",
            false
        );
        assert(_depositedBalanceOf(MAKER_WALLET, address(tokenA)) == 1 ether);
        assert(
            _depositedBalanceOf(address(flashloanReceiver), address(tokenA)) ==
                0
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 CANCEL
    //////////////////////////////////////////////////////////////*/

    function testCancel_failNotOfferer() public {
        IClearing.SignedOrder memory order = _generateSignedOrder(
            MAKER_PRIVATE_KEY,
            address(tokenA),
            0,
            address(tokenB),
            0,
            TAKER_WALLET,
            address(simpleMatch),
            ""
        );
        vm.expectRevert();
        _cancel(TAKER_WALLET, order);
    }

    function testCancel_failAlreadyCancelled() public {
        IClearing.SignedOrder memory order = _generateSignedOrder(
            MAKER_PRIVATE_KEY,
            address(tokenA),
            0,
            address(tokenB),
            0,
            MAKER_WALLET,
            address(simpleMatch),
            ""
        );

        _cancel(MAKER_WALLET, order);
        vm.expectRevert();
        _cancel(MAKER_WALLET, order);
    }

    function testCancel_success() public {
        _cancel(
            MAKER_WALLET,
            _generateSignedOrder(
                MAKER_PRIVATE_KEY,
                address(tokenA),
                0,
                address(tokenB),
                0,
                MAKER_WALLET,
                address(simpleMatch),
                ""
            )
        );
    }
}
