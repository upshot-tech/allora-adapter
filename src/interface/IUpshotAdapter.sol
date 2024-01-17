// SPDX-License-Identifier: BUSL-1.1

import { IAggregator } from '../interface/IAggregator.sol';
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


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

struct UpshotAdapterNumericData {
    SignedNumericData[] signedNumericData;
    bytes extraData;
}

struct TopicConfig {
    string title;
    address owner;
    uint48 dataProviderQuorum;
    uint48 dataValiditySeconds;
    IAggregator aggregator;
    bool ownerSwitchedOn;
    bool adminSwitchedOn;
}

/// @dev The struct for a topic, using a set for valid data providers 
struct Topic { 
    TopicConfig config;
    EnumerableSet.AddressSet validDataProviders;
}

struct TopicValue { 
    uint192 recentValue;
    uint64 recentValueTime;
}

// TODO reduce data structure size
/// @dev The struct for viewing a topic, which can be loaded into memory and returned
struct TopicView { 
    TopicConfig config;
    address[] validDataProviders;
}

// ***************************************************************
// * ======================= INTERFACE ========================= *
// ***************************************************************

/**
 * @title Upshot Adapter Interface
 */
interface IUpshotAdapter {

    /**
     * @notice Get a verified piece of numeric data for a given topic
     * 
     * @param pd The numeric data to aggregate
     */
    function verifyData(UpshotAdapterNumericData calldata pd) external returns (uint256 numericValue);

    /**
     * @notice Get a verified piece of numeric data for a given topic without mutating state
     * 
     * @param pd The numeric data to aggregate
     */
    function verifyDataViewOnly(UpshotAdapterNumericData calldata pd) external view returns (uint256 numericValue);

    /**
     * @notice Get the topic data for a given topicId
     * 
     * @param topicId The topicId to get the topic data for
     * @return topicView The topic data
     */
    function getTopic(uint256 topicId) external view returns (TopicView memory topicView);

    /**
     * @notice Get the topic data for a given topicId
     * 
     * @param topicId The topicId to get the topic data for
     * @param extraData The extraData to get the topic data for
     * @return topicValue The topic data
     */
    function getTopicValue(uint256 topicId, bytes calldata extraData) external view returns (TopicValue memory);
}
