pragma solidity 0.8.17;
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeERC20} from "./libs/SafeERC20.sol";
import {BitMaps} from "./libs/BitMaps.sol";
import {IAoriV2} from "./interfaces/IAoriV2.sol";
import {IAoriHook} from "./interfaces/IAoriHook.sol";
import {IERC1271} from "./interfaces/IERC1271.sol";
import {IERC165} from "./interfaces/IERC165.sol";
import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol";
import {SignatureChecker} from "./libs/SignatureChecker.sol";

/// @title AoriV2
/// @notice An implementation of the settlement contract used for the Aori V2 protocol
/// @dev The current implementation regards a serverSigner that signs off on matching details
///      of which the private key behind this wallet should be protected. If the private key is
///      compromised, no funds can technically be stolen but orders will be matched in a way
///      that is not intended i.e FIFO.
contract AoriV2 is IAoriV2 {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using BitMaps for BitMaps.BitMap;
    using SafeERC20 for IERC20;
    using SignatureChecker for address;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    // @notice Orders are stored using buckets of bitmaps to allow
    //         for potential gas optimisations by a bucket's bitmap
    //         having been written to previously. Programmatic
    //         users can also attempt to mine for specific order
    //         hashes to hit a used bucket.
    BitMaps.BitMap private orderStatus;

    // @notice 2D mapping of balances. The primary index is by
    //         owner and the secondary index is by token.
    mapping(address => mapping(address => uint256)) private balances;

    // @notice Server signer wallet used to verify matching for
    //         this contract. Again, the key should be protected.
    //         In the case that a key is compromised, no funds
    //         can be stolen but orders may be matched in an
    //         unfair way. A new contract would need to be
    //         deployed with a new deployer.
    address public immutable serverSigner;

    // @notice Taker fee recipient and fee in bips
    address private takerFeeRecipient;
    uint256 private takerFeeInBips;
    uint256 private constant TAKER_FEE_DENOMINATOR = 10_000;

    // @notice Reentrancy guard
    bool private locked;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _serverSigner) {
        require(
            _serverSigner != address(0),
            "Server signer cannot be zero address"
        );
        serverSigner = _serverSigner;
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Main bulk of the logic for validating and settling orders
    /// @param matching   The matching details of the orders to settle
    /// @param serverSignature  The signature of the server signer
    /// @dev Server signer signature must be signed with the private key of the server signer
    function settleOrders(
        MatchingDetails calldata matching,
        bytes calldata serverSignature,
        bytes calldata hookData
    ) external payable {
        /*//////////////////////////////////////////////////////////////
                           SPECIFIC ORDER VALIDATION
        //////////////////////////////////////////////////////////////*/

        // Check start and end times of orders
        require(
            matching.makerOrder.startTime <= block.timestamp,
            "Maker order start time is in the future"
        );
        require(
            matching.takerOrder.startTime <= block.timestamp,
            "Taker order start time is in the future"
        );
        require(
            matching.makerOrder.endTime >= block.timestamp,
            "Maker order end time has already passed"
        );
        require(
            matching.takerOrder.endTime >= block.timestamp,
            "Taker order end time has already passed"
        );

        // And the chainId is the set chainId for the order such that
        // we can protect against cross-chain signature replay attacks.
        require(
            matching.makerOrder.chainId == matching.takerOrder.chainId,
            "Maker order's chainid does not match taker order's chainid"
        );

        require(
            matching.makerOrder.chainId == block.chainid,
            "Order's chainid does not match current chainid"
        );

        // Check zone
        require(
            matching.makerOrder.zone == matching.takerOrder.zone,
            "Maker order's zone does not match taker order's zone"
        );
        require(
            matching.makerOrder.zone == address(this),
            "Zone does not match this contract"
        );

        /*//////////////////////////////////////////////////////////////
                              SIGNATURE VALIDATION
        //////////////////////////////////////////////////////////////*/

        // Compute order hashes of both orders
        bytes32 makerHash = getOrderHash(matching.makerOrder);
        bytes32 takerHash = getOrderHash(matching.takerOrder);

        // Check maker signature
        if (matching.makerOrder.inputAmount > 0) {
            (
                uint8 makerV,
                bytes32 makerR,
                bytes32 makerS
            ) = signatureIntoComponents(matching.makerSignature);
            require(
                matching.makerOrder.offerer.isValidSignatureNow(
                    keccak256(
                        abi.encodePacked(
                            "\x19Ethereum Signed Message:\n32",
                            makerHash
                        )
                    ),
                    abi.encodePacked(makerR, makerS, makerV)
                ),
                "Maker signature does not correspond to order details"
            );
        }

        // Check taker signature
        if (matching.takerOrder.inputAmount > 0) {
            (
                uint8 takerV,
                bytes32 takerR,
                bytes32 takerS
            ) = signatureIntoComponents(matching.takerSignature);
            require(
                matching.takerOrder.offerer.isValidSignatureNow(
                    keccak256(
                        abi.encodePacked(
                            "\x19Ethereum Signed Message:\n32",
                            takerHash
                        )
                    ),
                    abi.encodePacked(takerR, takerS, takerV)
                ),
                "Taker signature does not correspond to order details"
            );
        }

        /*//////////////////////////////////////////////////////////////
                              MATCHING VALIDATION
        //////////////////////////////////////////////////////////////*/

        // Check that tokens are for each other
        require(
            matching.makerOrder.inputToken == matching.takerOrder.outputToken,
            "Maker order input token is not equal to taker order output token"
        );
        require(
            matching.makerOrder.outputToken == matching.takerOrder.inputToken,
            "Maker order output token is not equal to taker order input token"
        );

        // Check input/output amounts
        require(
            matching.takerOrder.outputAmount <= matching.makerOrder.inputAmount,
            "Taker order output amount is more than maker order input amount"
        );
        require(
            withFee(matching.makerOrder.outputAmount, takerFeeInBips) <=
                matching.takerOrder.inputAmount,
            "Maker order output amount is more than taker order input amount"
        );

        // Check order statuses and make sure that they haven't been settled
        require(
            !BitMaps.get(orderStatus, uint256(makerHash)),
            "Maker order has been settled"
        );
        require(
            !BitMaps.get(orderStatus, uint256(takerHash)),
            "Taker order has been settled"
        );

        (
            uint8 serverV,
            bytes32 serverR,
            bytes32 serverS
        ) = signatureIntoComponents(serverSignature);

        // Ensure that the server has signed off on these matching details
        require(
            serverSigner.isValidSignatureNow(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        getMatchingHash(matching)
                    )
                ),
                abi.encodePacked(serverR, serverS, serverV)
            ),
            "Server signature does not correspond to order details"
        );

        // These two lines alone cost 40k gas due to storage in the worst case :sad:
        // This itself is a form of non-reentrancy due to the order status checks above.
        BitMaps.set(orderStatus, uint256(makerHash));
        BitMaps.set(orderStatus, uint256(takerHash));

        /*//////////////////////////////////////////////////////////////
                             SETTLE: TAKER-TO-MAKER
        //////////////////////////////////////////////////////////////*/

        // (Taker ==> Maker) processing
        // Either subtract from in-contract balance or transfer from taker's wallet
        if (
            balances[matching.takerOrder.offerer][
                matching.takerOrder.inputToken
            ] >= matching.takerOrder.inputAmount
        ) {
            balances[matching.takerOrder.offerer][
                matching.takerOrder.inputToken
            ] -= matching.takerOrder.inputAmount;
        } else {
            // Transfer from their own wallet - move taker order assets into here
            IERC20(matching.takerOrder.inputToken).safeTransferFrom(
                matching.takerOrder.offerer,
                address(this),
                matching.takerOrder.inputAmount
            );
        }

        // If maker would like their output tokens withdrawn to them, they can do so.
        // Enabling the maker to receive the tokens first before we process their side
        // for them to have native flash-loan-like capabilities.
        if (!matching.makerOrder.toWithdraw) {
            // Add balance
            balances[matching.makerOrder.recipient][
                matching.makerOrder.outputToken
            ] += matching.makerOrder.outputAmount;
        } else {
            IERC20(matching.makerOrder.outputToken).safeTransfer(
                matching.makerOrder.recipient,
                matching.makerOrder.outputAmount
            );
        }

        /*//////////////////////////////////////////////////////////////
                             SETTLE: MAKER-TO-TAKER
        //////////////////////////////////////////////////////////////*/

        // (Maker ==> Taker) processing
        // Before-Aori-Trade Hook
        if (
            matching.makerOrder.offerer.code.length > 0 &&
            IERC165(matching.makerOrder.offerer).supportsInterface(
                IAoriHook.beforeAoriTrade.selector
            )
        ) {
            bool success = IAoriHook(matching.makerOrder.offerer)
                .beforeAoriTrade(matching, hookData);
            require(success, "BeforeAoriTrade hook failed");
        }

        // Subtract from maker's balance
        if (
            balances[matching.makerOrder.offerer][
                matching.makerOrder.inputToken
            ] >= matching.makerOrder.inputAmount
        ) {
            balances[matching.makerOrder.offerer][
                matching.makerOrder.inputToken
            ] -= matching.makerOrder.inputAmount;
        } else {
            IERC20(matching.makerOrder.inputToken).safeTransferFrom(
                matching.makerOrder.offerer,
                address(this),
                matching.makerOrder.inputAmount
            );
        }

        // Taker receive tokens
        if (!matching.takerOrder.toWithdraw) {
            balances[matching.takerOrder.recipient][
                matching.takerOrder.outputToken
            ] += matching.takerOrder.outputAmount;
        } else {
            IERC20(matching.takerOrder.outputToken).safeTransfer(
                matching.takerOrder.recipient,
                matching.takerOrder.outputAmount
            );
        }

        /*//////////////////////////////////////////////////////////////
                            SETTLE: FEE PROCESSING
        //////////////////////////////////////////////////////////////*/

        // First, pay taker fee
        if (takerFeeInBips > 0) {
            balances[takerFeeRecipient][matching.makerOrder.outputToken] +=
                withFee(matching.makerOrder.outputAmount, takerFeeInBips) -
                matching.makerOrder.outputAmount;
        }

        // Fee processing
        // The fee recipient keeps any excess
        if (
            matching.makerOrder.inputAmount > matching.takerOrder.outputAmount
        ) {
            balances[matching.feeRecipient][matching.takerOrder.outputToken] +=
                matching.makerOrder.inputAmount -
                matching.takerOrder.outputAmount;
        }

        if (
            matching.takerOrder.inputAmount >
            withFee(matching.makerOrder.outputAmount, takerFeeInBips)
        ) {
            balances[matching.feeRecipient][matching.makerOrder.outputToken] +=
                matching.takerOrder.inputAmount -
                withFee(matching.makerOrder.outputAmount, takerFeeInBips);
        }

        /*//////////////////////////////////////////////////////////////
                             POST-TRADE PROCESSING
        //////////////////////////////////////////////////////////////*/

        // Emit
        emit FeeReceived(
            matching.feeRecipient,
            matching.feeTag,
            matching.makerOrder.inputToken,
            matching.makerOrder.inputAmount - matching.takerOrder.outputAmount,
            matching.makerOrder.outputToken,
            matching.takerOrder.inputAmount -
                withFee(matching.makerOrder.outputAmount, takerFeeInBips)
        );

        // After-Aori-Trade Hook
        if (
            matching.makerOrder.offerer.code.length > 0 &&
            IERC165(matching.makerOrder.offerer).supportsInterface(
                IAoriHook.afterAoriTrade.selector
            )
        ) {
            bool success = IAoriHook(matching.makerOrder.offerer)
                .afterAoriTrade(matching, hookData);
            require(success, "AfterAoriTrade hook failed");
        }

        // Emit event
        emit OrdersSettled(
            makerHash, // makerHash
            takerHash, // takerHash
            getMatchingHash(matching), // matchingHash
            matching.tradeId, // tradeId
            matching.makerOrder.offerer, // maker
            matching.takerOrder.offerer, // taker
            matching.makerOrder.zone, // zone
            matching.makerOrder.chainId // chainId
        );
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
        uint256 _amount
    ) external {
        uint256 startingBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        // Add delta of balance to the account
        balances[_account][_token] +=
            IERC20(_token).balanceOf(address(this)) -
            startingBalance;
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraws tokens from the contract
    /// @param _token The token to withdraw
    /// @param _amount The amount to withdraw
    function withdraw(address _token, uint256 _amount) external {
        // Lock
        require(!locked, "Reentrancy guard");
        locked = true;

        uint256 startingBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, _amount);
        balances[msg.sender][_token] -=
            startingBalance -
            IERC20(_token).balanceOf(address(this));

        locked = false;
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
                               TAKER FEE
    //////////////////////////////////////////////////////////////*/

    function setTakerFee(
        address _newFeeRecipient,
        uint256 _newFeeInBips
    ) external {
        require(
            _newFeeRecipient != address(0),
            "Fee recipient cannot be zero address"
        );
        require(_newFeeInBips < 100, "Fee in bips cannot be greater than 1%");

        takerFeeRecipient = _newFeeRecipient;
        takerFeeInBips = _newFeeInBips;
    }

    function getTakerFee()
        external
        view
        returns (address feeRecipient, uint256 feeInBips)
    {
        feeRecipient = takerFeeRecipient;
        feeInBips = takerFeeInBips;
    }

    function withFee(
        uint256 amount,
        uint256 feeInBips
    ) public view returns (uint256) {
        return
            (amount * (TAKER_FEE_DENOMINATOR + feeInBips)) /
            TAKER_FEE_DENOMINATOR;
    }

    function withoutFee(
        uint256 amount,
        uint256 feeInBips
    ) public view returns (uint256) {
        return
            (amount * TAKER_FEE_DENOMINATOR) /
            (TAKER_FEE_DENOMINATOR + feeInBips);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function hasSettled(bytes32 orderHash) public view returns (bool settled) {
        settled = BitMaps.get(orderStatus, uint256(orderHash));
    }

    function balanceOf(
        address _account,
        address _token
    ) public view returns (uint256 balance) {
        balance = balances[_account][_token];
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function signatureIntoComponents(
        bytes memory signature
    ) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) {
            v += 27;
        }
    }

    function getOrderHash(
        Order memory order
    ) public view returns (bytes32 orderHash) {
        orderHash = keccak256(
            abi.encodePacked(
                order.offerer,
                order.inputToken,
                order.inputAmount,
                order.outputToken,
                order.outputAmount,
                order.recipient,
                // =====
                order.zone,
                order.chainId,
                order.startTime,
                order.endTime,
                // =====
                order.toWithdraw
            )
        );
    }

    function getMatchingHash(
        MatchingDetails calldata matching
    ) public view returns (bytes32 matchingHash) {
        matchingHash = keccak256(
            abi.encodePacked(
                matching.tradeId,
                // =====
                matching.makerSignature,
                matching.takerSignature,
                // =====
                matching.feeTag,
                matching.feeRecipient
            )
        );
    }
}
