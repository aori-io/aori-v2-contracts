pragma solidity 0.8.24;

interface IFlashLoanReceiver {
    function receiveFlashLoan(
        address token,
        uint256 amount,
        bytes calldata data,
        bool receiveToken
    ) external;
}
