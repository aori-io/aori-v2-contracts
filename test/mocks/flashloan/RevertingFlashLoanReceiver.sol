pragma solidity 0.8.24;

import { IFlashLoanReceiver } from "../../../contracts/interfaces/IFlashLoanReceiver.sol";

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