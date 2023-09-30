// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface IFeeHandler {
    /**
     * @notice Handle fees, sending them to the fee receivers
     * 
     * @param feeReceivers The addresses to send the fees to
     * @param extraData Extra data to be used by the fee handler
     */
    function handleFees(address[] memory feeReceivers, bytes memory extraData) external payable;

    /**
     * @notice The total fee to be paid
     */
    function totalFee() external view returns (uint256);
}
