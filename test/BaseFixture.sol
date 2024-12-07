pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SimpleFlashLoanReceiver} from "./mocks/flashloan/SimpleFlashLoanReceiver.sol";
import {RevertingFlashLoanReceiver} from "./mocks/flashloan/RevertingFlashLoanReceiver.sol";
import {NoopZone} from "./mocks/zones/NoopZone.sol";
import {RevertingZone} from "./mocks/zones/RevertingZone.sol";
import {MockSimpleMatch} from "./mocks/zones/MockSimpleMatch.sol";
import {OnlyReleaseZone} from "./mocks/zones/OnlyReleaseZone.sol";
import {SimpleToken} from "./mocks/tokens/SimpleToken.sol";
import {IClearing} from "../contracts/interfaces/IClearing.sol";
import {ClearingUtils} from "../contracts/libs/ClearingUtils.sol";

interface IERC20Mintable is IERC20 {
    function mint(uint256 amount) external;
}

contract BaseFixture is Test {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    IClearing.SignedOrder[] internal orders;

    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/

    address internal clearingInstance;

    /*//////////////////////////////////////////////////////////////
                                 MOCKS
    //////////////////////////////////////////////////////////////*/

    SimpleToken internal tokenA;
    SimpleToken internal tokenB;

    // Hooks
    // SimpleHook internal simpleHook;
    // RevertingHook internal revertHook;
    // FailingHook internal failingHook;
    // TrickFailingHook internal trickFailingHook;
    // UnauthedHook internal unauthedHook;

    // Loan Receivers
    SimpleFlashLoanReceiver internal flashloanReceiver;
    RevertingFlashLoanReceiver internal revertFlashloanReceiver;

    // Zones
    NoopZone internal noopZone;
    MockSimpleMatch internal simpleMatch;
    RevertingZone internal revertingZone;
    OnlyReleaseZone internal onlyReleaseZone;

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

    function setUp() public virtual {
        /*//////////////////////////////////////////////////////////////
                                   ADDRESSES
        //////////////////////////////////////////////////////////////*/

        SERVER_WALLET = address(vm.addr(SERVER_PRIVATE_KEY));
        FAKE_SERVER_WALLET = address(vm.addr(FAKE_SERVER_PRIVATE_KEY));
        MAKER_WALLET = address(vm.addr(MAKER_PRIVATE_KEY));
        FAKE_MAKER_WALLET = address(vm.addr(FAKE_MAKER_PRIVATE_KEY));
        TAKER_WALLET = address(vm.addr(TAKER_PRIVATE_KEY));
        FAKE_TAKER_WALLET = address(vm.addr(FAKE_TAKER_PRIVATE_KEY));
        SEARCHER_WALLET = address(vm.addr(SEARCHER_PRIVATE_KEY));

        vm.label(SERVER_WALLET, "Server Wallet");
        vm.label(FAKE_SERVER_WALLET, "Fake Server Wallet");
        vm.label(MAKER_WALLET, "Maker Wallet");
        vm.label(FAKE_MAKER_WALLET, "Fake Maker Wallet");
        vm.label(TAKER_WALLET, "Taker Wallet");
        vm.label(FAKE_TAKER_WALLET, "Fake Taker Wallet");

        /*//////////////////////////////////////////////////////////////
                                    MOCKS
        //////////////////////////////////////////////////////////////*/

        tokenA = new SimpleToken();
        tokenB = new SimpleToken();

        flashloanReceiver = new SimpleFlashLoanReceiver();
        revertFlashloanReceiver = new RevertingFlashLoanReceiver();

        noopZone = new NoopZone();
        simpleMatch = new MockSimpleMatch(address(clearingInstance));
        revertingZone = new RevertingZone();
        onlyReleaseZone = new OnlyReleaseZone(address(clearingInstance));

        vm.label(address(tokenA), "TokenA");
        vm.label(address(tokenB), "TokenB");

        vm.label(address(flashloanReceiver), "FlashloanReceiver");
        vm.label(address(revertFlashloanReceiver), "RevertFlashloanReceiver");
        vm.label(address(simpleMatch), "SimpleMatch");
        vm.label(address(revertingZone), "RevertingZone");
        vm.label(address(onlyReleaseZone), "OnlyReleaseZone");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _generateSignedOrder(
        uint256 _privateKey,
        address _inputToken,
        uint256 _inputAmount,
        address _outputToken,
        uint256 _outputAmount,
        address _recipient,
        address _zone,
        bytes memory _extraData
    ) public returns (IClearing.SignedOrder memory) {
        IClearing.Order memory order = IClearing.Order({
            offerer: vm.addr(_privateKey),
            inputToken: _inputToken,
            inputAmount: _inputAmount,
            outputToken: _outputToken,
            outputAmount: _outputAmount,
            recipient: _recipient,
            zone: _zone,
            chainId: uint160(block.chainid),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + 10 minutes),
            toWithdraw: false
        });

        bytes32 signatureMessage = ClearingUtils.getSignatureMessage(
            IClearing.SignedOrder({
                order: order,
                extraData: _extraData,
                signature: ""
            })
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    signatureMessage
                )
            )
        );

        return
            IClearing.SignedOrder({
                order: order,
                extraData: _extraData,
                signature: abi.encodePacked(r, s, v)
            });
    }

    /*//////////////////////////////////////////////////////////////
                             WALLET ACTIONS
    //////////////////////////////////////////////////////////////*/

    function _mint(address _from, address _token, uint256 _amount) public {
        vm.startPrank(_from);
        IERC20Mintable(_token).mint(_amount);
        vm.stopPrank();
    }

    function _approve(address _from, address _token, uint256 _amount) public {
        vm.startPrank(_from);
        IERC20(_token).approve(address(clearingInstance), _amount);
        vm.stopPrank();
    }

    function _mintAndApprove(
        address _from,
        address _token,
        uint256 _amount
    ) public {
        _mint(_from, _token, _amount);
        _approve(_from, _token, _amount);
    }

    function _deposit(address _from, address _token, uint256 _amount) public {
        vm.startPrank(_from);
        IClearing(clearingInstance).deposit(_from, _token, _amount, "");
        vm.stopPrank();
    }

    function _withdraw(address _from, address _token, uint256 _amount) public {
        vm.startPrank(_from);
        IClearing(clearingInstance).withdraw(msg.sender, _token, _amount, "");
        vm.stopPrank();
    }

    function _settle(
        uint256 _privateKey,
        IClearing.SignedOrder[] memory _orders,
        bytes memory _extraData
    ) public {
        address server = vm.addr(_privateKey);
        vm.startPrank(server);
        IClearing(clearingInstance).settle(_orders, _extraData);
        vm.stopPrank();
    }

    function _flashLoan(
        address _from,
        address _recipient,
        address _token,
        uint256 _amount,
        bytes memory _userData,
        bool _receiveToken
    ) public {
        vm.startPrank(_from);
        IClearing(clearingInstance).flash(
            _recipient,
            _token,
            _amount,
            _userData,
            _receiveToken
        );
        vm.stopPrank();
    }

    function _cancel(
        address _from,
        IClearing.SignedOrder memory _signedOrder
    ) public {
        vm.startPrank(_from);
        IClearing(clearingInstance).cancel(_signedOrder);
        vm.stopPrank();
    }

    function _depositedBalanceOf(
        address _account,
        address _token
    ) public view returns (uint256) {
        return IClearing(clearingInstance).balanceOf(_account, _token);
    }

    function _hasSettled(
        address _offerer,
        bytes32 _orderHash
    ) public view returns (bool) {
        return IClearing(clearingInstance).hasSettled(_offerer, _orderHash);
    }
}
