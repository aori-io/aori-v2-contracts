// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import { IExecutor } from "./IExecutor.sol";

interface IExecutorFeeLib {
    struct FeeParams {
        address priceFeed;
        uint32 dstEid;
        address sender;
        uint256 calldataSize;
        uint16 defaultMultiplierBps;
    }

    error NoOptions();
    error NativeAmountExceedsCap(uint256 amount, uint256 cap);
    error UnsupportedOptionType(uint8 optionType);
    error InvalidExecutorOptions(uint256 cursor);

    function getFeeOnSend(
        FeeParams calldata _params,
        IExecutor.DstConfig calldata _dstConfig,
        bytes calldata _options
    ) external returns (uint256 fee);

    function getFee(
        FeeParams calldata _params,
        IExecutor.DstConfig calldata _dstConfig,
        bytes calldata _options
    ) external view returns (uint256 fee);
}
