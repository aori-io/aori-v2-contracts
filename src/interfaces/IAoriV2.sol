pragma solidity 0.8.17;

interface IAoriV2 {

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Order {
        address offerer;
        address inputToken;
        uint256 inputAmount;
        uint256 inputChainId;
        address inputZone;
        address outputToken;
        uint256 outputAmount;
        uint256 outputChainId;
        address outputZone;
        uint256 startTime;
        uint256 endTime;
        uint256 salt;
        uint256 counter;
        bool toWithdraw;
    }

    struct MatchingDetails {
        Order makerOrder;
        Order takerOrder;

        bytes makerSignature;
        bytes takerSignature;
        uint256 blockDeadline;

        // Seat details
        uint256 seatNumber;
        address seatHolder;
        uint256 seatPercentOfFees;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OrdersSettled(
        bytes32 indexed makerHash,
        bytes32 indexed takerHash,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        bytes32 matchingHash
    );

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    function settleOrders(MatchingDetails calldata matching, bytes calldata serverSignature, bytes calldata hookData, bytes calldata options) external payable;

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function deposit(address _account, address _token, uint256 _amount) external;

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function withdraw(address _token, uint256 _amount) external;

    /*//////////////////////////////////////////////////////////////
                               FLASHLOAN
    //////////////////////////////////////////////////////////////*/

    function flashLoan(address recipient, address token, uint256 amount, bytes memory userData, bool receiveToken) external;

    /*//////////////////////////////////////////////////////////////
                                 COUNTER
    //////////////////////////////////////////////////////////////*/

    function incrementCounter() external;
    function getCounter() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                               TAKER FEE
    //////////////////////////////////////////////////////////////*/

    function setTakerFee(uint8 _takerFeeBips, address _takerFeeAddress) external;

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function hasOrderSettled(bytes32 orderHash) external view returns (bool settled);
    function balanceOf(address _account, address _token) external view returns (uint256 balance);

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function signatureIntoComponents(
        bytes memory signature
    ) external pure returns (
        uint8 v,
        bytes32 r,
        bytes32 s
    );
    function getOrderHash(Order memory order) external view returns (bytes32 orderHash);
    function getMatchingHash(MatchingDetails calldata matching) external view returns (bytes32 matchingHash);
}