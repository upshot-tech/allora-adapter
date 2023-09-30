// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IFeeHandler } from '../interface/IFeeHandler.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Math } from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract EvenFeeHandler is IFeeHandler, Ownable2Step {

    /// @inheritdoc IFeeHandler
    uint256 public override totalFee = 0.001 ether;

    /// @dev the portion of the total fee that goes to the protocol
    uint256 public protocolFeePortion = 0.2 ether;

    /// @dev the address that receives the protocol fee
    address public protocolFeeReceiver;

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    event UpshotOracleEvenFeeHandlerFeesHandled(address[] feeReceivers);
    event UpshotOracleEvenFeeHandlerAdminUpdatedTotalFee(uint256 totalFee);
    event UpshotOracleEvenFeeHandlerAdminUpdatedProtocolFeePortion(uint256 protocolFeePortion);
    event UpshotOracleEvenFeeHandlerAdminUpdatedProtocolFeeReceiver(address protocolFeeReceiver);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error UpshotOracleEvenFeeHandlerEthTransferFailed();


    /// @inheritdoc IFeeHandler
    function handleFees(
        address[] memory feeReceivers, 
        bytes memory
    ) external payable {
        uint256 protocolFee = Math.mulDiv(totalFee, protocolFeePortion, 1 ether);
        uint256 priceProviderFee = (totalFee - protocolFee) / feeReceivers.length;

        _safeTransferETH(protocolFeeReceiver, protocolFee);

        for (uint i = 0; i < feeReceivers.length; i++) {
            _safeTransferETH(feeReceivers[i], priceProviderFee);
        }

        emit UpshotOracleEvenFeeHandlerFeesHandled(feeReceivers);
    }

    // ***************************************************************
    // * ==================== INTERNAL HELPERS ===================== *
    // ***************************************************************
    /**
     * @notice Safely transfer ETH to an address
     * 
     * @param to The address to send ETH to
     * @param value The amount of ETH to send
     */
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) {
            revert UpshotOracleEvenFeeHandlerEthTransferFailed();
        }
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************
    /**
     * @notice Admin function to update the total fee to be paid
     * 
     * @param totalFee_ The total fee to be paid
     */
    function updateTotalFee(uint256 totalFee_) external onlyOwner {
        totalFee = totalFee_;

        emit UpshotOracleEvenFeeHandlerAdminUpdatedTotalFee(totalFee_);
    }

    /**
     * @notice Admin function to update the portion of the total fee that goes to the protocol
     * 
     * @param protocolFeePortion_ The portion of the total fee that goes to the protocol
     */
    function updateProtocolFeePortion(uint256 protocolFeePortion_) external onlyOwner {
        if (protocolFeePortion_ <= 1 ether) {
            protocolFeePortion = protocolFeePortion_;
        }

        emit UpshotOracleEvenFeeHandlerAdminUpdatedProtocolFeePortion(protocolFeePortion_);
    }

    /**
     * @notice Admin function to update the address that receives the protocol fee
     * 
     * @param protocolFeeReceiver_ The address that receives the protocol fee
     */
    function updateProtocolFeeReceiver(address protocolFeeReceiver_) external onlyOwner {
        protocolFeeReceiver = protocolFeeReceiver_;

        emit UpshotOracleEvenFeeHandlerAdminUpdatedProtocolFeeReceiver(protocolFeeReceiver_);
    }

}
