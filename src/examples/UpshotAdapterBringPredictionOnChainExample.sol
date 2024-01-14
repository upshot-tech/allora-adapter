// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IUpshotAdapter, Topic, TopicView, TopicValue, UpshotAdapterNumericData } from '../interface/IUpshotAdapter.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


/**
 * @title UpshotAdapterBringPredictionOnChainExample
 * @notice Example contract for using the Upshot adapter by bringing predictions on-chain
 */
contract UpshotAdapterBringPredictionOnChainExample is Ownable2Step {

    // Sepolia adapter Address
    IUpshotAdapter public upshotAdapter = IUpshotAdapter(0x4341a3F0a350C2428184a727BAb86e16D4ba7018);

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************

    /**
     * @notice Example for calling a protocol function with using an inedex value already stored on the
     *   Upshot Adapter, only if the value is not stale
     * 
     * @param protocolFunctionArgument An argument for the protocol function
     * @param topicId The id of the topic to use the most recent stored value for
     */
    function callProtocolFunctionWithExistingIndexValue(
        uint256 protocolFunctionArgument,
        uint256 topicId
    ) external payable {
        TopicValue memory topicValue = IUpshotAdapter(0x4341a3F0a350C2428184a727BAb86e16D4ba7018).getTopicValue(topicId, '');

        if (topicValue.recentValueTime + 1 hours < block.timestamp) {
            revert('UpshotAdapterBringPredictionOnChainExample: stale value');
        }

        _protocolFunctionRequiringPredictionValue(protocolFunctionArgument, topicValue.recentValue);
    }

    /**
     * @notice Example for calling a protocol function with a prediction value from the Upshot Adapter
     * 
     * @param protocolFunctionArgument An argument for the protocol function
     * @param upshotAdapterData The signed data from the Upshot Adapter
     */
    function callProtocolFunctionWithUpshotAdapterPredictionValue(
        uint256 protocolFunctionArgument,
        UpshotAdapterNumericData calldata upshotAdapterData
    ) external payable {
        uint256 value = IUpshotAdapter(0x4341a3F0a350C2428184a727BAb86e16D4ba7018).verifyData{value: msg.value}(upshotAdapterData);

        _protocolFunctionRequiringPredictionValue(protocolFunctionArgument, value);
    }

    function _protocolFunctionRequiringPredictionValue(uint256 protocolFunctionArgument, uint256 value) internal {
        // use arguments and value 
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Set the UpshotAdapter contract address
     * 
     * @param upshotAdapter_ The UpshotAdapter contract address
     */
    function setUpshotAdapterContract(IUpshotAdapter upshotAdapter_) external onlyOwner {
        upshotAdapter = upshotAdapter_;
    }
}
