pragma solidity 0.8.17;

import { IFlashLoanReceiver } from "../../../interfaces/IFlashLoanReceiver.sol";

contract SimpleFlashLoanReceiver is IFlashLoanReceiver {

    // Simple ghost variable
    uint256 public count;

    function receiveFlashLoan(
        address token,
        uint256 amount,
        bytes calldata data,
        bool receiveToken
    ) external {
        count++;
    }
}