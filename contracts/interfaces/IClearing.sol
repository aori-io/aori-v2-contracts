pragma solidity 0.8.24;

interface IClearing {
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
        bool toWithdraw;
    }

    struct SignedOrder {
        Order order;
        bytes extraData;
        bytes signature;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(
        address indexed from,
        address indexed account,
        address indexed token,
        uint256 amount,
        bytes extraData
    );

    event Withdraw(
        address indexed from,
        address indexed account,
        address indexed token,
        uint256 amount,
        bytes extraData
    );

    event Transfer(
        address indexed from,
        address indexed account,
        address indexed token,
        uint256 amount,
        bytes extraData
    );

    event Settled(
        bytes32 indexed orderHash,
        address indexed zone,
        address indexed offerer,
        Order order,
        bytes extraData
    );

    event Cancelled(
        bytes32 indexed orderHash,
        address indexed zone,
        address indexed offerer,
        Order order,
        bytes extraData
    );

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function settle(
        SignedOrder[] memory orders,
        bytes memory extraData
    ) external payable;

    function deposit(
        address account,
        address token,
        uint256 amount,
        bytes memory extraData
    ) external payable;

    function move(
        address to,
        address token,
        uint256 amount,
        bytes memory extraData
    ) external;

    function withdraw(
        address to,
        address token,
        uint256 amount,
        bytes memory extraData
    ) external;

    function flash(
        address recipient,
        address token,
        uint256 amount,
        bytes memory userData,
        bool receiveToken
    ) external;

    function cancel(SignedOrder memory signedOrder) external;

    function escrow(SignedOrder memory signedOrder) external;

    function release(SignedOrder memory signedOrder) external;

    function balanceOf(
        address account,
        address token
    ) external view returns (uint256);

    function hasSettled(
        address offerer,
        bytes32 orderHash
    ) external view returns (bool);
}
