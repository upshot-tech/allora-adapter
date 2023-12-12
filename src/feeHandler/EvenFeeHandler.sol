// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IFeeHandler } from '../interface/IFeeHandler.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Math } from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

struct EvenFeeHandlerConstructorArgs {
    address admin;
}

contract EvenFeeHandler is IFeeHandler, Ownable2Step {

    /// @dev the portion of the total fee that goes to the feed owner
    uint256 public feedOwnerPortion = 0.2 ether;

    /// @dev The fees accrued by each fee receiver
    mapping(address feeReciever => uint256 feesAccrued) public feesAccrued;

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    event UpshotAdapterV2EvenFeeHandlerFeesHandled(uint256 fee, address[] feeReceivers);
    event UpshotAdapterV2EvenFeeHandlerAdminUpdatedFeedOwnerFeePortion(uint256 feedOwnerPortion);
    event UpshotAdapterV2EvenFeeHandlerFeesClaimed(address claimer, uint256 fees);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error UpshotAdapterV2EvenFeeHandlerEthTransferFailed();
    error UpshotAdapterV2EvenFeeHandlerFeeTooLow();
    error UpshotAdapterV2EvenFeeHandlerInvalidFeedOwnerFeePortion();

    constructor(
        EvenFeeHandlerConstructorArgs memory args
    ) {
        _transferOwnership(args.admin);
    }

    /// @inheritdoc IFeeHandler
    function handleFees(
        address feedOwner, 
        address[] memory feeReceivers, 
        bytes memory
    ) external payable {
        uint256 fee = msg.value;

        if (fee == 0) {
            return;
        }

        if (fee < 1_000) {
            revert UpshotAdapterV2EvenFeeHandlerFeeTooLow();
        }

        // load once to save gas
        uint256 _feedOwnerPortion = feedOwnerPortion;

        uint256 feedOwnerFee = Math.mulDiv(fee, _feedOwnerPortion, 1 ether);
        uint256 priceProviderFee = (fee - feedOwnerFee) / feeReceivers.length;

        feesAccrued[feedOwner] += feedOwnerFee;

        for (uint i = 0; i < feeReceivers.length;) {
            feesAccrued[feeReceivers[i]] += priceProviderFee;

            unchecked {
                ++i;
            }
        }

        emit UpshotAdapterV2EvenFeeHandlerFeesHandled(fee, feeReceivers);
    }

    /**
     * @notice Claim fees accrued by the sender
     */
    function claimFees() external {
        uint256 feesOwed = feesAccrued[msg.sender];
        feesAccrued[msg.sender] = 0;

        _safeTransferETH(msg.sender, feesOwed);

        emit UpshotAdapterV2EvenFeeHandlerFeesClaimed(msg.sender, feesOwed);
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
            revert UpshotAdapterV2EvenFeeHandlerEthTransferFailed();
        }
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Admin function to update the portion of the total fee that goes to the feed owner
     * 
     * @param feedOwnerPortion_ The new portion of the total fee that goes to the feed owner
     */
    function updateFeedOwnerPortion(uint256 feedOwnerPortion_) external onlyOwner {
        if (feedOwnerPortion_ > 1 ether) {
            revert UpshotAdapterV2EvenFeeHandlerInvalidFeedOwnerFeePortion();
        }

        feedOwnerPortion = feedOwnerPortion_;

        emit UpshotAdapterV2EvenFeeHandlerAdminUpdatedFeedOwnerFeePortion(feedOwnerPortion_);
    }
}
