// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface IFeeHandler {
    function handleFees(address[] memory feeReceivers, bytes memory extraData) external payable;

    function totalFee() external view returns (uint256);
}
