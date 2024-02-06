pragma solidity 0.8.17;
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { SafeERC20 } from "./libs/SafeERC20.sol";
import { BitMaps } from "./libs/BitMaps.sol";
import { IAoriV2 } from "./interfaces/IAoriV2.sol";
import { IAoriHook } from "./interfaces/IAoriHook.sol";
import { IERC1271 } from "./interfaces/IERC1271.sol";
import { IERC165 } from "./interfaces/IERC165.sol";
import { IFlashLoanReceiver } from "./interfaces/IFlashLoanReceiver.sol";
import { SignatureChecker } from "./libs/SignatureChecker.sol";

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

    // @notice Counters for each address. A user can cancel orders
    //         by incrementing their counter, similar to how
    //         Seaport does it.
    mapping(address => uint256) private addressCounter;

    // @notice Server signer wallet used to verify matching for
    //         this contract. Again, the key should be protected.
    //         In the case that a key is compromised, no funds
    //         can be stolen but orders may be matched in an
    //         unfair way. A new contract would need to be
    //         deployed with a new deployer.
    address private immutable serverSigner;
    // Taker fee in bips i.e 100 = 1%
    uint8 private takerFeeBips;
    // Fees are paid to this address
    address private takerFeeAddress;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor(address _serverSigner) {
        serverSigner = _serverSigner;
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Main bulk of the logic for validating and settling orders
    /// @param matching   The matching details of the orders to settle
    /// @param serverSignature  The signature of the server signer
    /// @dev Server signer signature must be signed with the private key of the server signer
    function settleOrders(MatchingDetails calldata matching, bytes calldata serverSignature, bytes calldata hookData, bytes calldata options) external payable {

        /*//////////////////////////////////////////////////////////////
                           SPECIFIC ORDER VALIDATION
        //////////////////////////////////////////////////////////////*/

        // Check start and end times of orders
        require(matching.makerOrder.startTime <= block.timestamp, "Maker order start time is in the future");
        require(matching.takerOrder.startTime <= block.timestamp, "Taker order start time is in the future");
        require(matching.makerOrder.endTime >= block.timestamp, "Maker order end time has already passed");
        require(matching.takerOrder.endTime >= block.timestamp, "Taker order end time has already passed");

        // Check counters (note: we allow orders with a counter greater than or equal to the current counter to be executed immediately)
        require(matching.makerOrder.counter >= addressCounter[matching.makerOrder.offerer], "Counter of maker order is too low");
        require(matching.takerOrder.counter >= addressCounter[matching.takerOrder.offerer], "Counter of taker order is too low");

        // And the chainId is the set chainId for the order such that
        // we can protect against cross-chain signature replay attacks.
        require(matching.makerOrder.inputChainId == matching.takerOrder.outputChainId, "Maker order's input chainid does not match taker order's output chainid");
        require(matching.takerOrder.inputChainId == matching.makerOrder.outputChainId, "Taker order's input chainid does not match maker order's output chainid");

        // Check zone
        require(matching.makerOrder.inputZone == matching.takerOrder.outputZone, "Maker order's input zone does not match taker order's output zone");
        require(matching.takerOrder.inputZone == matching.makerOrder.outputZone, "Taker order's input zone does not match maker order's output zone");

        // Single-chained orders via this contract
        require(matching.makerOrder.inputChainId == block.chainid, "Maker order's input chainid does not match current chainid");
        require(matching.takerOrder.inputChainId == block.chainid, "Taker order's input chainid does not match current chainid");
        require(matching.makerOrder.inputZone == address(this), "Maker order's input zone does not match this contract");
        require(matching.takerOrder.inputZone == address(this), "Taker order's input zone does not match this contract");

        // Compute order hashes of both orders
        bytes32 makerHash = getOrderHash(matching.makerOrder);
        bytes32 takerHash = getOrderHash(matching.takerOrder);

        // Check maker signature
        (uint8 makerV, bytes32 makerR, bytes32 makerS) = signatureIntoComponents(matching.makerSignature);
        require(matching.makerOrder.offerer.isValidSignatureNow(
            keccak256(abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                makerHash
            )),
            abi.encodePacked(makerR, makerS, makerV)),
            "Maker signature does not correspond to order details"
        );

        (uint8 takerV, bytes32 takerR, bytes32 takerS) = signatureIntoComponents(matching.takerSignature);
        require(matching.takerOrder.offerer.isValidSignatureNow(
            keccak256(abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                takerHash
            )),
            abi.encodePacked(takerR, takerS, takerV)),
            "Taker signature does not correspond to order details"
        );

        // Check that tokens are for each other
        require(matching.makerOrder.inputToken == matching.takerOrder.outputToken,
            "Maker order input token is not equal to taker order output token");
        require(matching.makerOrder.outputToken == matching.takerOrder.inputToken,
            "Maker order output token is not equal to taker order input token");

        // Check input/output amounts
        require(matching.takerOrder.outputAmount <= matching.makerOrder.inputAmount,
            "Taker order output amount is more than maker order input amount");
        require(matching.makerOrder.outputAmount <= adjustedWithFee(matching.takerOrder.inputAmount),
            "Maker order output amount is more than taker order input amount");

        // Check order statuses and make sure that they haven't been settled
        require(!BitMaps.get(orderStatus, uint256(makerHash)), "Maker order has been settled");
        require(!BitMaps.get(orderStatus, uint256(takerHash)), "Taker order has been settled");

        /*//////////////////////////////////////////////////////////////
                              MATCHING VALIDATION
        //////////////////////////////////////////////////////////////*/

        // Ensure that block deadline to execute has not passed
        require(
            matching.blockDeadline >= block.number,
            "Order execution deadline has passed"
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = signatureIntoComponents(serverSignature);

        // Ensure that the server has signed off on these matching details
        require(
            serverSigner ==
                ecrecover(
                    keccak256(
                        abi.encodePacked(
                            "\x19Ethereum Signed Message:\n32",
                            getMatchingHash(matching)
                        )
                    ),
                    serverV, serverR, serverS
                ),
            "Server signature does not correspond to order details"
        );

        /*//////////////////////////////////////////////////////////////
                                     SETTLE
        //////////////////////////////////////////////////////////////*/

        // These two lines alone cost 40k gas due to storage in the worst case :sad:
        // This itself is a form of non-reentrancy due to the order status checks above.
        BitMaps.set(orderStatus, uint256(makerHash));
        BitMaps.set(orderStatus, uint256(takerHash));

        // (Taker ==> Maker) processing
        if (balances[matching.takerOrder.offerer][matching.takerOrder.inputToken] >= matching.takerOrder.inputAmount) {
            balances[matching.takerOrder.offerer][matching.takerOrder.inputToken] -= matching.takerOrder.inputAmount;
        } else {
            // Transfer from their own wallet - move taker order assets into here
            IERC20(matching.takerOrder.inputToken).safeTransferFrom(matching.takerOrder.offerer, address(this), matching.takerOrder.inputAmount);
        }

        // If maker would like their output tokens withdrawn to them, they can do so.
        // Enabling the maker to receive the tokens first before we process their side
        // for them to have native flash-loan-like capabilities.
        if (!matching.makerOrder.toWithdraw) {
            // Add balance
            balances[matching.makerOrder.offerer][matching.makerOrder.outputToken] += matching.makerOrder.outputAmount;
        } else {
            IERC20(matching.makerOrder.outputToken).safeTransfer(
                matching.makerOrder.offerer,
                matching.makerOrder.outputAmount
            );
        }

        // Fee calculation
        if (takerFeeBips != 0) {
            // Apply fees
            balances[takerFeeAddress][matching.takerOrder.inputToken] += adjustedTakerFee(matching.takerOrder.inputAmount) * (100 - matching.seatPercentOfFees) / 100;

            if (matching.seatPercentOfFees != 0) {
                balances[matching.seatHolder][matching.takerOrder.inputToken] += adjustedTakerFee(matching.takerOrder.inputAmount) * matching.seatPercentOfFees / 100;
            }
        }
        
        // (Maker ==> Taker) processing
        // Before-Aori-Trade Hook
        if (matching.makerOrder.offerer.code.length > 0 && IERC165(matching.makerOrder.offerer).supportsInterface(IAoriHook.beforeAoriTrade.selector)) {
            (bool success) = IAoriHook(matching.makerOrder.offerer).beforeAoriTrade(matching, hookData);
            require(success, "BeforeAoriTrade hook failed");
        }

        if (balances[matching.makerOrder.offerer][matching.makerOrder.inputToken] >= matching.makerOrder.inputAmount) {
            balances[matching.makerOrder.offerer][matching.makerOrder.inputToken] -= matching.makerOrder.inputAmount;
        } else {
            IERC20(matching.makerOrder.inputToken).safeTransferFrom(matching.makerOrder.offerer, address(this), matching.makerOrder.inputAmount);
        }

        if (!matching.takerOrder.toWithdraw) {
            balances[matching.takerOrder.offerer][matching.takerOrder.outputToken] += matching.takerOrder.outputAmount;
        } else {
            IERC20(matching.takerOrder.outputToken).safeTransfer(
                matching.takerOrder.offerer,
                matching.takerOrder.outputAmount
            );
        }

        // After-Aori-Trade Hook
        if (matching.makerOrder.offerer.code.length > 0 && IERC165(matching.makerOrder.offerer).supportsInterface(IAoriHook.afterAoriTrade.selector)) {
            (bool success) = IAoriHook(matching.makerOrder.offerer).afterAoriTrade(matching, hookData);
            require(success, "AfterAoriTrade hook failed");
        }

        // Settler processing

        // Whoever settles the order gets to keep any excess
        if (matching.takerOrder.outputAmount > matching.makerOrder.inputAmount) {
            balances[tx.origin][matching.takerOrder.outputToken] += matching.takerOrder.outputAmount - matching.makerOrder.inputAmount;
        }

        if (matching.makerOrder.outputAmount > adjustedWithoutFee(matching.takerOrder.inputAmount)) {
            balances[tx.origin][matching.makerOrder.outputToken] += matching.makerOrder.outputAmount - adjustedWithoutFee(matching.takerOrder.inputAmount);
        }

        // Emit events
        emit OrdersSettled(
            makerHash,
            takerHash,
            matching.makerOrder.inputToken,
            matching.makerOrder.outputToken,
            matching.makerOrder.inputAmount,
            matching.makerOrder.outputAmount,
            getMatchingHash(matching)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits tokens to the contract
    /// @param _account The account to deposit to
    /// @param _token The token to deposit
    /// @param _amount The amount to deposit
    function deposit(address _account, address _token, uint256 _amount) external {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        balances[_account][_token] += _amount;
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraws tokens from the contract
    /// @param _token The token to withdraw
    /// @param _amount The amount to withdraw
    function withdraw(address _token, uint256 _amount) external {
        balances[msg.sender][_token] -= (_amount);
        IERC20(_token).safeTransfer(msg.sender, _amount);
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
    function flashLoan(address recipient, address token, uint256 amount, bytes memory userData, bool receiveToken) external {

        // Flash loan
        if (receiveToken) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            balances[recipient][token] += amount;
        }
        
        // call the recipient's receiveFlashLoan
        IFlashLoanReceiver(recipient).receiveFlashLoan(token, amount, userData, receiveToken);

        if (receiveToken) {
            IERC20(token).safeTransferFrom(recipient, address(this), amount);
        } else {
            balances[recipient][token] -= amount;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 NONCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Increment the counter of the sender. Note that this is
    ///         counter is not exactly a sequence number. It is a
    ///         counter that is incremented to denote
    function incrementCounter() external {
        addressCounter[msg.sender] += 1;
    }

    function getCounter() external view returns (uint256) {
        return addressCounter[msg.sender];
    }

    function version() external view returns (string memory) {
        return "2.0";
    }

    /*//////////////////////////////////////////////////////////////
                               TAKER FEE
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the taker fee address and bips
    /// @dev Can only be called by the server signer
    function setTakerFee(uint8 _takerFeeBips, address _takerFeeAddress) external {
        require(msg.sender == serverSigner, "Taker fee address must be server signer");
        require(_takerFeeBips <= 100, "Taker fee bips must be less than 1%");

        if (takerFeeBips != _takerFeeBips) {
            takerFeeBips = _takerFeeBips;
        }

        if (takerFeeAddress != _takerFeeAddress) {
            takerFeeAddress = _takerFeeAddress;
        }
    }

    function adjustedWithFee(uint256 _amount) internal view returns (uint256 amountWithFee) {
        amountWithFee = _amount * (10000 + takerFeeBips) / 10000;
    }

    function adjustedWithoutFee(uint256 _amountWithFee) internal view returns (uint256 amountWithoutFee) {
        amountWithoutFee = _amountWithFee * 10000 / (10000 + takerFeeBips);
    }

    function adjustedTakerFee(uint256 _amount) internal view returns (uint256 totalTakerFee) {
        totalTakerFee = _amount * takerFeeBips;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function hasOrderSettled(bytes32 orderHash) public view returns (bool settled) {
        settled = BitMaps.get(orderStatus, uint256(orderHash));
    }

    function balanceOf(address _account, address _token) public view returns (uint256 balance) {
        balance = balances[_account][_token];
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function signatureIntoComponents(
        bytes memory signature
    ) public pure returns (
        uint8 v,
        bytes32 r,
        bytes32 s
    ) {
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) {
            v += 27;
        }
    }

    function getOrderHash(Order memory order) public view returns (bytes32 orderHash) {
        orderHash = keccak256(
            abi.encodePacked(
                order.offerer,
                order.inputToken,
                order.inputAmount,
                order.inputChainId,
                order.inputZone,
                order.outputToken,
                order.outputAmount,
                order.outputChainId,
                order.outputZone,
                order.startTime,
                order.endTime,
                order.salt,
                order.counter,
                order.toWithdraw
            )
        );
    }

    function getMatchingHash(MatchingDetails calldata matching) public view returns (bytes32 matchingHash) {
        matchingHash = keccak256(
            abi.encodePacked(
                matching.makerSignature,
                matching.takerSignature,
                matching.blockDeadline,
                matching.seatNumber,
                matching.seatHolder,
                matching.seatPercentOfFees
            )
        );
    }
}