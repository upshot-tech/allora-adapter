// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IAlloraAdapter, TopicValue, AlloraAdapterNumericData } from '../interface/IAlloraAdapter.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


/**
 * @title AlloraAdapterBringPredictionOnChainExample
 * @notice Example contract for using the Allora adapter by bringing predictions on-chain
 */
contract AlloraAdapterBringPredictionOnChainExample is Ownable2Step {

    // Sepolia adapter Address
    IAlloraAdapter public alloraAdapter = IAlloraAdapter(0x4341a3F0a350C2428184a727BAb86e16D4ba7018);

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************

    /**
     * @notice Example for calling a protocol function with using an inedex value already stored on the
     *   Allora Adapter, only if the value is not stale
     * 
     * @param protocolFunctionArgument An argument for the protocol function
     * @param topicId The id of the topic to use the most recent stored value for
     */
    function callProtocolFunctionWithExistingValue(
        uint256 protocolFunctionArgument,
        uint256 topicId
    ) external payable {
        TopicValue memory topicValue = IAlloraAdapter(0x4341a3F0a350C2428184a727BAb86e16D4ba7018).getTopicValue(topicId, '');

        if (topicValue.recentValueTime + 1 hours < block.timestamp) {
            revert('AlloraAdapterBringPredictionOnChainExample: stale value');
        }

        _protocolFunctionRequiringPredictionValue(protocolFunctionArgument, topicValue.recentValue);
    }

    /**
     * @notice Example for calling a protocol function with a prediction value from the Allora Adapter
     * 
     * @param protocolFunctionArgument An argument for the protocol function
     * @param alloraAdapterData The signed data from the Allora Adapter
     */
    function callProtocolFunctionWithAlloraAdapterPredictionValue(
        uint256 protocolFunctionArgument,
        AlloraAdapterNumericData calldata alloraAdapterData
    ) external payable {
        (uint256 value,,,) = IAlloraAdapter(0x4341a3F0a350C2428184a727BAb86e16D4ba7018).verifyData(alloraAdapterData);

        _protocolFunctionRequiringPredictionValue(protocolFunctionArgument, value);
    }

    function _protocolFunctionRequiringPredictionValue(uint256 protocolFunctionArgument, uint256 value) internal {
        // use arguments and value 
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Set the AlloraAdapter contract address
     * 
     * @param alloraAdapter_ The AlloraAdapter contract address
     */
    function setAlloraAdapterContract(IAlloraAdapter alloraAdapter_) external onlyOwner {
        alloraAdapter = alloraAdapter_;
    }
}
