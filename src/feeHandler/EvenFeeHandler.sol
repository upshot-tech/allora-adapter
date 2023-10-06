// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IFeeHandler } from '../interface/IFeeHandler.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Math } from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

struct EvenFeeHandlerConstructorArgs {
    address admin;
    address protocolFeeReceiver;
}


contract EvenFeeHandler is IFeeHandler, Ownable2Step {

    /// @dev the portion of the total fee that goes to the protocol
    uint256 public protocolFeePortion = 0.2 ether;

    /// @dev the address that receives the protocol fee
    address public protocolFeeReceiver;

    /// @dev the address that receives the protocol fee
    mapping(address feeReciever => uint256 feesAccrued) public feesAccrued;

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    event UpshotOracleV2EvenFeeHandlerFeesHandled(uint256 fee, address[] feeReceivers);
    event UpshotOracleV2EvenFeeHandlerAdminUpdatedTotalFee(uint256 totalFee);
    event UpshotOracleV2EvenFeeHandlerAdminUpdatedProtocolFeePortion(uint256 protocolFeePortion);
    event UpshotOracleV2EvenFeeHandlerAdminUpdatedProtocolFeeReceiver(address protocolFeeReceiver);
    event UpshotOracleV2EvenFeeHandlerFeesClaimed(address claimer, uint256 fees);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error UpshotOracleV2EvenFeeHandlerEthTransferFailed();
    error UpshotOracleV2EvenFeeHandlerFeeTooLow();
    error UpshotOracleV2EvenFeeHandlerInvalidProtocolFeePortion();

    constructor(
        EvenFeeHandlerConstructorArgs memory args
    ) {
        _transferOwnership(args.admin);

        protocolFeeReceiver = args.protocolFeeReceiver;

        emit UpshotOracleV2EvenFeeHandlerAdminUpdatedProtocolFeeReceiver(args.protocolFeeReceiver);
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

        feesAccrued[protocolFeeReceiver] += protocolFee;

        for (uint i = 0; i < feeReceivers.length;) {
            feesAccrued[feeReceivers[i]] += priceProviderFee;

            unchecked {
                ++i;
            }
        }

        emit UpshotOracleV2EvenFeeHandlerFeesHandled(fee, feeReceivers);
    }

    /**
     * @notice Claim fees accrued by the sender
     */
    function claimFees() external {
        uint256 feesOwed = feesAccrued[msg.sender];
        feesAccrued[msg.sender] = 0;

        _safeTransferETH(msg.sender, feesOwed);

        emit UpshotOracleV2EvenFeeHandlerFeesClaimed(msg.sender, feesOwed);
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
