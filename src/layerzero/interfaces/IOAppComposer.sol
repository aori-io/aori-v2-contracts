// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { ILayerZeroComposer } from "./ILayerZeroComposer.sol";

/**
 * @title IOAppComposer
 * @dev This interface defines the OApp Composer, allowing developers to inherit only the OApp package without the protocol.
 */
// solhint-disable-next-line no-empty-blocks
interface IOAppComposer is ILayerZeroComposer {}
