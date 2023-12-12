// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IUpshotAdapter, Topic, TopicView, TopicConfig, UpshotAdapterNumericData } from '../interface/IUpshotAdapter.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


/**
 * @title UpshotAdapterViewPredictionExample
 * @notice Example contract for viewing a prediction for a topic that is updated elsewhere
 */
contract UpshotAdapterViewPredictionExample is Ownable2Step {

    // Sepolia adapter Address
    IUpshotAdapter public upshotAdapter = IUpshotAdapter(0xdD3C703221c7F00Fe0E2d8cdb5403ca7760CDd4c);

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
    function setUpshotAdapterContract(IUpshotAdapter upshotAdapter_) external onlyOwner {
        upshotAdapter = upshotAdapter_;
    }
}
