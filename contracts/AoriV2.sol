pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeERC20} from "./libs/SafeERC20.sol";
import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol";
import {IZone} from "./interfaces/IZone.sol";
import {IClearing} from "./interfaces/IClearing.sol";
import {ClearingUtils} from "./libs/ClearingUtils.sol";
import {tuint256, tbytes32, taddress} from "transient-goodies/TransientPrimitives.sol";
import {EIP712} from "solady/utils/EIP712.sol";

contract AoriV2 is IClearing, EIP712 {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    // @notice 2D mapping of balances. The primary index is by
    //         owner and the secondary index is by token.
    mapping(address => mapping(address => uint256)) private balances;

    // @notice Mapping of settled orders
    mapping(address => mapping(bytes32 => bool)) private settledOrders;
    mapping(address => mapping(bytes32 => bool)) private cancelledOrders;

    /*//////////////////////////////////////////////////////////////
                            TRANSIENT STATE
    //////////////////////////////////////////////////////////////*/

    tuint256 private CLEARING_PHASE;
    uint256 private constant CLEARING_PHASE_OFF = 0;
    uint256 private constant CLEARING_PHASE_ON = 1;

    mapping(bytes32 => tuint256) private CONTEXT_SETTLED_ORDERS;
    uint256 private constant ESCROW_BIT = 1;
    uint256 private constant RELEASE_BIT = 2;

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    // @notice Settle orders of the same zone (use a multi-call to settle multiple zones)
    function settle(
        SignedOrder[] calldata orders,
        bytes calldata extraData
    ) external payable {
        CLEARING_PHASE.set(CLEARING_PHASE_ON);

        // Check that all orders are for the same chain (this one, to prevent cross-chain replay attacks) and zone
        address zone = address(0);
        for (uint256 i = 0; i < orders.length; i++) {
            require(
                orders[i].order.chainId == block.chainid,
                "Order chainId does not match"
            );

            if (zone == address(0) || zone == address(this)) {
                zone = orders[i].order.zone;
            } else if (
                orders[i].order.zone != address(0) &&
                orders[i].order.zone != address(this)
            ) {
                require(
                    orders[i].order.zone == zone,
                    "Orders are not for the same zone"
                );
            }

            require(
                !isCancelled(
                    orders[i].order.offerer,
                    ClearingUtils.getOrderHash(orders[i].order)
                ),
                "Order has been cancelled"
            );
        }

        // Handle settlement
        if (orders.length > 0) {
            require(zone != address(0), "Zone is not set");
            IZone(zone).handleSettlement(orders, extraData);
        }

        // Check that all orders have been paid
        for (uint256 i = 0; i < orders.length; i++) {
            bytes32 orderHash = ClearingUtils.getOrderHash(orders[i].order);

            require(
                CONTEXT_SETTLED_ORDERS[orderHash].get() & RELEASE_BIT ==
                    RELEASE_BIT,
                "Order's output assets have not been paid"
            );

            if (!hasSettled(orders[i].order.offerer, orderHash)) {
                settledOrders[orders[i].order.offerer][orderHash] = true;

                emit Settled(
                    orderHash, // orderHash
                    orders[i].order.zone, // zone
                    orders[i].order.offerer, // offerer
                    orders[i].order,
                    orders[i].extraData
                );
            }
        }

        CLEARING_PHASE.set(CLEARING_PHASE_OFF);
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits tokens to the contract
    /// @param _account The account to deposit to
    /// @param _token The token to deposit
    /// @param _amount The amount to deposit
    function deposit(
        address _account,
        address _token,
        uint256 _amount,
        bytes memory _extraData
    ) external payable {
        // Determine the amount to transfer, being the max of the amount to send and the sender's balance
        uint256 theirBalance = IERC20(_token).balanceOf(msg.sender);
        uint256 amountToTransfer = _amount > theirBalance
            ? theirBalance
            : _amount;
        require(amountToTransfer > 0, "Amount to transfer is 0");

        // Transfer the amount to the contract
        uint256 startingBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransferFrom(
            msg.sender,
            address(this),
            amountToTransfer
        );

        // Add delta of balance to the account
        uint256 delta = IERC20(_token).balanceOf(address(this)) -
            startingBalance;
        balances[_account][_token] += delta;
        emit Deposit(msg.sender, _account, _token, delta, _extraData);

        // Call handleDeposit function on the zone
        if (msg.sender != _account && _account.code.length > 0) {
            IZone(_account).handleDeposit(
                msg.sender,
                _token,
                delta,
                _extraData
            );
        }
    }

    function move(
        address to,
        address token,
        uint256 amount,
        bytes memory extraData
    ) external {
        // Move the max of the amount to transfer and the sender's balance
        uint256 theirBalance = balances[msg.sender][token];
        uint256 amountToTransfer = amount > theirBalance
            ? theirBalance
            : amount;
        require(amountToTransfer > 0, "Amount to transfer is 0");

        balances[msg.sender][token] -= amountToTransfer;
        balances[to][token] += amountToTransfer;

        emit Transfer(msg.sender, to, token, amountToTransfer, extraData);

        if (msg.sender != to && to.code.length > 0) {
            IZone(to).handleDeposit(
                msg.sender,
                token,
                amountToTransfer,
                extraData
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraws tokens from the contract
    /// @param _token The token to withdraw
    /// @param _amount The amount to withdraw
    function withdraw(
        address _to,
        address _token,
        uint256 _amount,
        bytes memory _extraData
    ) external {
        // They must be withdrawing less than their balance
        uint256 theirBalance = balances[msg.sender][_token];
        require(
            _amount <= theirBalance,
            "Amount to withdraw is greater than their balance"
        );
        uint256 amountToTransfer = _amount;

        // Transfer the amount to the recipient
        balances[msg.sender][_token] -= amountToTransfer;
        IERC20(_token).safeTransfer(_to, amountToTransfer);
        emit Withdraw(msg.sender, _to, _token, amountToTransfer, _extraData);
    }

    /*//////////////////////////////////////////////////////////////
                               FLASH LOAN
    //////////////////////////////////////////////////////////////*/

    /// @notice Flash loan tokens
    /// @param recipient The recipient
    /// @param token The token
    /// @param amount The amount
    /// @param userData User data to pass to the recipient
    /// @param receiveToken Whether to receive the token directly or fine to keep in the contract for gas efficiency
    function flash(
        address recipient,
        address token,
        uint256 amount,
        bytes memory userData,
        bool receiveToken
    ) external {
        uint256 startingBalance = IERC20(token).balanceOf(address(this));

        // Flash loan
        if (receiveToken) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            balances[recipient][token] += amount;
        }

        // call the recipient's receiveFlashLoan
        IFlashLoanReceiver(recipient).receiveFlashLoan(
            token,
            amount,
            userData,
            receiveToken
        );

        // Repay the flash loan
        if (receiveToken) {
            IERC20(token).safeTransferFrom(recipient, address(this), amount);
        } else {
            balances[recipient][token] -= amount;
        }

        // Set invariant that the contract should have at least the starting balance
        // or more before and after the flash loan
        require(
            IERC20(token).balanceOf(address(this)) >= startingBalance,
            "Flash loan not repaid"
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 CANCEL
    //////////////////////////////////////////////////////////////*/

    function cancel(SignedOrder memory signedOrder) external {
        require(
            msg.sender == signedOrder.order.offerer,
            "Only offerer can cancel"
        );

        require(
            ClearingUtils.verifyOrderSignature(signedOrder),
            "Signature does not correspond to order details"
        );

        bytes32 orderHash = ClearingUtils.getOrderHash(signedOrder.order);
        require(
            !cancelledOrders[signedOrder.order.offerer][orderHash],
            "Order has already been cancelled"
        );
        cancelledOrders[signedOrder.order.offerer][orderHash] = true;

        emit Cancelled(
            orderHash,
            signedOrder.order.zone,
            signedOrder.order.offerer,
            signedOrder.order,
            signedOrder.extraData
        );
    }

    /*//////////////////////////////////////////////////////////////
                              ZONE ACTIONS
    //////////////////////////////////////////////////////////////*/

    function escrow(SignedOrder memory signedOrder) external {
        require(
            CLEARING_PHASE.get() == CLEARING_PHASE_ON,
            "Not in clearing phase"
        );

        require(
            signedOrder.order.startTime <= block.timestamp,
            "Order start time is in the future"
        );
        require(
            signedOrder.order.endTime >= block.timestamp,
            "Order end time has already passed"
        );

        // Check zone
        require(
            signedOrder.order.zone == msg.sender ||
                signedOrder.order.zone == address(0) ||
                signedOrder.order.zone == address(this),
            "Order zone does not match"
        );

        // And the chainId is the set chainId for the order such that
        // we can protect against cross-chain signature replay attacks.
        require(
            signedOrder.order.chainId == block.chainid,
            "Order chainId does not match"
        );

        bytes32 orderHash = ClearingUtils.getOrderHash(signedOrder.order);

        // Check that the order has not been settled
        require(
            !hasSettled(signedOrder.order.offerer, orderHash),
            "Order has been settled"
        );

        require(
            (CONTEXT_SETTLED_ORDERS[orderHash].get() & ESCROW_BIT) !=
                ESCROW_BIT,
            "Order's input assets have already been escrowed"
        );

        if (signedOrder.order.inputAmount > 0) {
            require(
                ClearingUtils.verifyOrderSignature(signedOrder),
                "Signature does not correspond to order details"
            );
        }

        CONTEXT_SETTLED_ORDERS[orderHash].set(
            CONTEXT_SETTLED_ORDERS[orderHash].get() | ESCROW_BIT
        );

        // If the input amount is 0, we don't need to escrow anything
        if (signedOrder.order.inputAmount == 0) {
            return;
        }

        if (
            balances[signedOrder.order.offerer][signedOrder.order.inputToken] >
            signedOrder.order.inputAmount
        ) {
            balances[signedOrder.order.offerer][
                signedOrder.order.inputToken
            ] -= signedOrder.order.inputAmount;
        } else {
            // Move assets from offerer into this contract
            IERC20(signedOrder.order.inputToken).safeTransferFrom(
                signedOrder.order.offerer,
                address(this),
                signedOrder.order.inputAmount
            );
        }

        balances[msg.sender][signedOrder.order.inputToken] += signedOrder
            .order
            .inputAmount;
    }

    function release(SignedOrder memory signedOrder) external {
        require(
            CLEARING_PHASE.get() == CLEARING_PHASE_ON,
            "Not in clearing phase"
        );

        bytes32 orderHash = ClearingUtils.getOrderHash(signedOrder.order);

        require(
            signedOrder.order.startTime <= block.timestamp,
            "Order start time is in the future"
        );
        require(
            signedOrder.order.endTime >= block.timestamp,
            "Order end time has already passed"
        );

        // Check zone
        require(
            signedOrder.order.zone == msg.sender ||
                signedOrder.order.zone == address(0) ||
                signedOrder.order.zone == address(this),
            "Order zone does not match"
        );

        // And the chainId is the set chainId for the order such that
        // we can protect against cross-chain signature replay attacks.
        require(
            signedOrder.order.chainId == block.chainid,
            "Order chainId does not match"
        );

        // Check that the order has not been settled
        require(
            !hasSettled(signedOrder.order.offerer, orderHash),
            "Order has been settled"
        );

        require(
            (CONTEXT_SETTLED_ORDERS[orderHash].get() & RELEASE_BIT) !=
                RELEASE_BIT,
            "Order's output assets have already been paid"
        );

        if (signedOrder.order.inputAmount > 0) {
            require(
                ClearingUtils.verifyOrderSignature(signedOrder),
                "Signature does not correspond to order details"
            );
        }

        CONTEXT_SETTLED_ORDERS[orderHash].set(
            CONTEXT_SETTLED_ORDERS[orderHash].get() | RELEASE_BIT
        );

        // If order.outputAmount is 0, we don't need to release anything
        if (signedOrder.order.outputAmount == 0) {
            return;
        }

        balances[msg.sender][signedOrder.order.outputToken] -= signedOrder
            .order
            .outputAmount;

        if (signedOrder.order.toWithdraw) {
            IERC20(signedOrder.order.outputToken).safeTransfer(
                signedOrder.order.recipient,
                signedOrder.order.outputAmount
            );
        } else {
            balances[signedOrder.order.recipient][
                signedOrder.order.outputToken
            ] += signedOrder.order.outputAmount;
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function hasSettled(
        address offerer,
        bytes32 orderHash
    ) public view returns (bool) {
        return settledOrders[offerer][orderHash];
    }

    function isCancelled(
        address offerer,
        bytes32 orderHash
    ) public view returns (bool) {
        return cancelledOrders[offerer][orderHash];
    }

    function balanceOf(
        address _account,
        address _token
    ) public view returns (uint256 balance) {
        balance = balances[_account][_token];
    }

    function getOrderHash(
        IClearing.Order memory order
    ) public pure returns (bytes32) {
        return ClearingUtils.getOrderHash(order);
    }

    function getSignatureMessage(
        IClearing.SignedOrder memory signedOrder
    ) public pure returns (bytes32) {
        return ClearingUtils.getSignatureMessage(signedOrder);
    }

    function verifyOrderSignature(
        IClearing.SignedOrder memory signedOrder
    ) public view returns (bool) {
        return ClearingUtils.verifyOrderSignature(signedOrder);
    }

    /*//////////////////////////////////////////////////////////////
                                EIP-712
    //////////////////////////////////////////////////////////////*/

    function _domainNameAndVersion()
        internal
        view
        override
        returns (string memory name, string memory version)
    {
        name = "Aori";
        version = "v2.0";
    }
}
