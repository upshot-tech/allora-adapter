// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IUpshotAdapter, Topic, TopicView, TopicConfig, UpshotAdapterNumericData } from '../interface/IUpshotAdapter.sol';
import { UpshotAdapter } from '../UpshotAdapter.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


/**
 * @title UpshotAdapterViewPredictionExample
 * @notice Example contract for viewing a prediction for a topic that is updated elsewhere
 */
contract UpshotAdapterViewPredictionExample is Ownable2Step {

    // Sepolia adapter Address
    UpshotAdapter public upshotAdapter = UpshotAdapter(0x091Db6CB55773F6D60Eaffd0060bd79021A5F6A2);

    constructor () {
        _transferOwnership(msg.sender);
    }

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************

    /**
     * @notice Example for viewing a prediction for a topic that is updated
     * 
     * @param topicId The topic to view the prediction for
     * @return prediction The prediction for the topic
     * @return predictionTimestamp The timestamp of the prediction
     */
    function viewPredictionForTopic(
        uint256 topicId
    ) external view returns (uint256 prediction, uint256 predictionTimestamp) {
        TopicView memory topicView = upshotAdapter.getTopic(topicId);

        return (topicView.config.recentValue, topicView.config.recentValueTime);
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Set the UpshotAdapter contract address
     * 
     * @param upshotAdapter_ The UpshotAdapter contract address
     */
    function setUpshotAdapterContract(UpshotAdapter upshotAdapter_) external onlyOwner {
        upshotAdapter = upshotAdapter_;
    }
}
