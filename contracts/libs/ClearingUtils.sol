pragma solidity ^0.8.24;

import {IClearing} from "../interfaces/IClearing.sol";
import {SignatureChecker} from "./SignatureChecker.sol";

library ClearingUtils {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SignatureChecker for address;

    /*//////////////////////////////////////////////////////////////
                            ORDER VALIDATION
    //////////////////////////////////////////////////////////////*/

    function getOrderHash(
        IClearing.Order memory order
    ) internal pure returns (bytes32) {
        return
            keccak256(
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

    function getSignatureMessage(
        IClearing.SignedOrder memory signedOrder
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    getOrderHash(signedOrder.order),
                    signedOrder.extraData
                )
            );
    }

    function verifyOrderSignature(
        IClearing.SignedOrder memory signedOrder
    ) internal view returns (bool) {
        (uint8 v, bytes32 r, bytes32 s) = signatureIntoComponents(
            signedOrder.signature
        );

        // Allow for signing by either standard compact-hashing (getSignatureMessage) or EIP-712 (TODO:)
        bytes32 quickSignatureMessage = getSignatureMessage(signedOrder);

        return
            signedOrder.order.offerer.isValidSignatureNow(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        quickSignatureMessage
                    )
                ),
                abi.encodePacked(r, s, v)
            );
    }

    function signatureIntoComponents(
        bytes memory signature
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) {
            v += 27;
        }
    }

    /*//////////////////////////////////////////////////////////////
                          SEQUENCE VALIDATION
    //////////////////////////////////////////////////////////////*/

    function getSequenceMessage(
        IClearing.SignedOrder[] memory signedOrders,
        bytes memory extraData
    ) internal pure returns (bytes32) {
        bytes32[] memory orderHashes;

        for (uint i; i < signedOrders.length; i++) {
            orderHashes[i] = getSignatureMessage(signedOrders[i]);
        }

        return keccak256(abi.encodePacked(orderHashes, extraData));
    }

    function verifySequenceSignature(
        IClearing.SignedOrder[] memory signedOrders,
        bytes memory extraData,
        bytes memory signature,
        address expectedSigner
    ) internal view returns (bool) {
        (uint8 v, bytes32 r, bytes32 s) = signatureIntoComponents(signature);
        bytes32 quickSignatureMessage = getSequenceMessage(
            signedOrders,
            extraData
        );

        return
            expectedSigner.isValidSignatureNow(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        quickSignatureMessage
                    )
                ),
                abi.encodePacked(r, s, v)
            );
    }

    /*//////////////////////////////////////////////////////////////
                                EIP-712
    //////////////////////////////////////////////////////////////*/

    function _eip712_ORDER_TYPE_HASH() internal pure returns (bytes32) {
        return
            keccak256(
                "Order(address offerer,address inputToken,uint256 inputAmount,address outputToken,uint256 outputAmount,address recipient,uint256 zone,uint160 chainId,uint32 startTime,uint32 endTime,bool toWithdraw)"
            );
    }

    function _eip712_hashOrder(
        IClearing.Order memory order
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _eip712_ORDER_TYPE_HASH(),
                    order.offerer,
                    order.inputToken,
                    order.inputAmount,
                    order.outputToken,
                    order.outputAmount,
                    order.recipient,
                    order.zone,
                    order.chainId,
                    order.startTime,
                    order.endTime,
                    order.toWithdraw
                )
            );
    }

    function _eip712_SIGNEDORDER_TYPE_HASH() internal pure returns (bytes32) {
        return keccak256("SignedOrder(Order order,bytes extraData)");
    }

    function _eip712_hashSignedOrder(
        IClearing.Order memory order,
        bytes memory extraData
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(_eip712_SIGNEDORDER_TYPE_HASH(), order, extraData)
            );
    }

    // TODO: add in domain fetch and digest creation
}
