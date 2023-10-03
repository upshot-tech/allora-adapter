// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IFeeHandler } from '../interface/IFeeHandler.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Math } from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract EvenFeeHandler is IFeeHandler, Ownable2Step {

    /// @dev the portion of the total fee that goes to the protocol
    uint256 public protocolFeePortion = 0.2 ether;

    /// @dev the address that receives the protocol fee
    address public protocolFeeReceiver;

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    event UpshotOracleV2EvenFeeHandlerFeesHandled(uint256 fee, address[] feeReceivers);
    event UpshotOracleV2EvenFeeHandlerAdminUpdatedTotalFee(uint256 totalFee);
    event UpshotOracleV2EvenFeeHandlerAdminUpdatedProtocolFeePortion(uint256 protocolFeePortion);
    event UpshotOracleV2EvenFeeHandlerAdminUpdatedProtocolFeeReceiver(address protocolFeeReceiver);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error UpshotOracleV2EvenFeeHandlerEthTransferFailed();
    error UpshotOracleV2EvenFeeHandlerFeeTooLow();
    error UpshotOracleV2EvenFeeHandlerInvalidProtocolFeePortion();

    constructor(
        address admin_,
        address protocolFeeReceiver_
    ) {
        _transferOwnership(admin_);

        protocolFeeReceiver = protocolFeeReceiver_;

        emit UpshotOracleV2EvenFeeHandlerAdminUpdatedProtocolFeeReceiver(protocolFeeReceiver_);
    }


    /// @inheritdoc IFeeHandler
    function handleFees(
        address[] memory feeReceivers, 
        bytes memory
    ) external payable {
        uint256 fee = msg.value;

        if (fee == 0) {
          return;
        }

        if (fee < 1_000) {
            revert UpshotOracleV2EvenFeeHandlerFeeTooLow();
        }

        uint256 protocolFee = Math.mulDiv(fee, protocolFeePortion, 1 ether);
        uint256 priceProviderFee = (fee - protocolFee) / feeReceivers.length;

        _safeTransferETH(protocolFeeReceiver, protocolFee);

        for (uint i = 0; i < feeReceivers.length;) {
            _safeTransferETH(feeReceivers[i], priceProviderFee);

            unchecked {
                ++i;
            }
        }

        emit UpshotOracleV2EvenFeeHandlerFeesHandled(fee, feeReceivers);
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
            revert UpshotOracleV2EvenFeeHandlerEthTransferFailed();
        }
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Admin function to update the portion of the total fee that goes to the protocol
     * 
     * @param protocolFeePortion_ The portion of the total fee that goes to the protocol
     */
    function updateProtocolFeePortion(uint256 protocolFeePortion_) external onlyOwner {
        if (protocolFeePortion_ > 1 ether) {
            revert UpshotOracleV2EvenFeeHandlerInvalidProtocolFeePortion();
        }

        protocolFeePortion = protocolFeePortion_;

        emit UpshotOracleV2EvenFeeHandlerAdminUpdatedProtocolFeePortion(protocolFeePortion_);
    }

    /**
     * @notice Admin function to update the address that receives the protocol fee
     * 
     * @param protocolFeeReceiver_ The address that receives the protocol fee
     */
    function updateProtocolFeeReceiver(address protocolFeeReceiver_) external onlyOwner {
        protocolFeeReceiver = protocolFeeReceiver_;

        emit UpshotOracleV2EvenFeeHandlerAdminUpdatedProtocolFeeReceiver(protocolFeeReceiver_);
    }

}
