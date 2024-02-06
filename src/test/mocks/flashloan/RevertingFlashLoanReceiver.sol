pragma solidity 0.8.17;

import { IFlashLoanReceiver } from "../../../interfaces/IFlashLoanReceiver.sol";

contract RevertingFlashLoanReceiver is IFlashLoanReceiver {

    // Simple ghost variable
    uint256 public count;

    // Note: do not use in production
    function receiveFlashLoan(
        address token,
        uint256 amount,
        bytes calldata data,
        bool receiveToken
    ) external {
        revert("revert");
    }
}