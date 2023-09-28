// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IFeeHandler } from '../interface/IFeeHandler.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Math } from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract EvenFeeHandler is IFeeHandler, Ownable2Step {

    uint256 public override totalFee = 0.001 ether;

    uint256 public protocolFeePortion = 0.2 ether;

    address public protocolFeeReceiver;

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************
    // TODO

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************
    error UpshotOracleEvenFeeHandlerEthTransferFailed();


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
    }

    // ***************************************************************
    // * ==================== INTERNAL HELPERS ===================== *
    // ***************************************************************
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) {
            revert UpshotOracleEvenFeeHandlerEthTransferFailed();
        }
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************
    function updateTotalFee(uint256 totalFee_) external onlyOwner {
        totalFee = totalFee_;
    }

    function updateProtocolFeePortion(uint256 protocolFeePortion_) external onlyOwner {
        if (protocolFeePortion_ <= 1 ether) {
            protocolFeePortion = protocolFeePortion_;
        }
    }

    function updateProtocolFeeReceiver(address protocolFeeReceiver_) external onlyOwner {
        protocolFeeReceiver = protocolFeeReceiver_;
    }

}
