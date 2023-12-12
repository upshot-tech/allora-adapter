// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IOracle, Topic, TopicView, TopicConfig, UpshotOracleNumericData } from '../interface/IOracle.sol';
import { Oracle } from '../Oracle.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


/**
 * @title OracleViewPredictionExample
 * @notice Example contract for viewing a prediction for a topic that is updated
 */
contract OracleViewPredictionExample is Ownable2Step {

    // Sepolia oracle Address
    Oracle public upshotOracle = Oracle(0x091Db6CB55773F6D60Eaffd0060bd79021A5F6A2);

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
        TopicView memory topicView = upshotOracle.getTopic(topicId);

        return (topicView.config.recentValue, topicView.config.recentValueTime);
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Set the Upshot Oracle contract address
     * 
     * @param upshotOracle_ The Upshot Oracle contract address
     */
    function setUpshotOracleContract(Oracle upshotOracle_) external onlyOwner {
        upshotOracle = upshotOracle_;
    }
}
