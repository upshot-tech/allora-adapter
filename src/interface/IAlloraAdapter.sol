// SPDX-License-Identifier: BUSL-1.1

import { IAggregator } from '../interface/IAggregator.sol';


pragma solidity ^0.8.0;

// ***************************************************************
// * ========================= STRUCTS ========================= *
// ***************************************************************

struct NumericData {
    uint256 topicId;
    uint256 timestamp;
    uint256 numericValue; 
    bytes extraData;
}

struct SignedNumericData { 
    bytes signature;
    NumericData numericData;
}

struct AlloraAdapterNumericData {
    SignedNumericData[] signedNumericData;
    bytes extraData;
}

struct TopicValue { 
    uint192 recentValue;
    uint64 recentValueTime;
}

// ***************************************************************
// * ======================= INTERFACE ========================= *
// ***************************************************************

/**
 * @title Allora Adapter Interface
 */
interface IAlloraAdapter {

    /**
     * @notice Get a verified piece of numeric data for a given topic
     * 
     * @param nd The numeric data to aggregate
     */
    function verifyData(AlloraAdapterNumericData memory nd) external returns (
        uint256 numericValue, 
        uint256 topicId, 
        address[] memory dataProviders, 
        bytes memory extraData
    );

    /**
     * @notice Get a verified piece of numeric data for a given topic without mutating state
     * 
     * @param pd The numeric data to aggregate
     */
    function verifyDataViewOnly(AlloraAdapterNumericData calldata pd) external view returns (
        uint256 numericValue, 
        uint256 topicId, 
        address[] memory dataProviders, 
        bytes memory extraData
    );

    /**
     * @notice Get the topic data for a given topicId
     * 
     * @param topicId The topicId to get the topic data for
     * @param extraData The extraData to get the topic data for
     * @return topicValue The topic data
     */
    function getTopicValue(uint256 topicId, bytes calldata extraData) external view returns (TopicValue memory);
}
