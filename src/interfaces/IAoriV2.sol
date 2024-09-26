pragma solidity 0.8.17;

interface IAoriV2 {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Order {
        address offerer;
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 outputAmount;
        address recipient;
        // =====
        address zone;
        uint160 chainId;
        uint32 startTime;
        uint32 endTime;
        // =====
        uint32 counter;
        bool toWithdraw;
    }

    struct MatchingDetails {
        Order makerOrder;
        Order takerOrder;
        // =====
        bytes makerSignature;
        bytes takerSignature;
        // =====
        string feeTag;
        address feeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeeReceived(
        address indexed feeRecipient,
        string indexed feeTag,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 outputAmount
    );

    event OrdersSettled(
        bytes32 indexed makerHash,
        bytes32 indexed takerHash,
        address maker,
        address taker,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        address zone,
        uint160 chainId,
        bytes32 matchingHash
    );

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    function settleOrders(
        MatchingDetails calldata matching,
        bytes calldata serverSignature,
        bytes calldata hookData
    ) external payable;

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function deposit(
        address _account,
        address _token,
        uint256 _amount
    ) external;

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function withdraw(address _token, uint256 _amount) external;

    /*//////////////////////////////////////////////////////////////
                               FLASHLOAN
    //////////////////////////////////////////////////////////////*/

    function flashLoan(
        address recipient,
        address token,
        uint256 amount,
        bytes memory userData,
        bool receiveToken
    ) external;

    /*//////////////////////////////////////////////////////////////
                                 COUNTER
    //////////////////////////////////////////////////////////////*/

    function incrementCounter() external;
    function getCounter() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function hasOrderSettled(
        bytes32 orderHash
    ) external view returns (bool settled);
    function balanceOf(
        address _account,
        address _token
    ) external view returns (uint256 balance);

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function signatureIntoComponents(
        bytes memory signature
    ) external pure returns (uint8 v, bytes32 r, bytes32 s);
    function getOrderHash(
        Order memory order
    ) external view returns (bytes32 orderHash);
    function getMatchingHash(
        MatchingDetails calldata matching
    ) external view returns (bytes32 matchingHash);
}
