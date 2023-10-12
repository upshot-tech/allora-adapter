// SPDX-License-Identifier: BUSL-1.1

import { IAggregator } from '../interface/IAggregator.sol';
import { IFeeHandler } from '../interface/IFeeHandler.sol';
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


pragma solidity ^0.8.0;

// ***************************************************************
// * ========================= STRUCTS ========================= *
// ***************************************************************

struct NumericData {
    uint64 feedId;
    uint64 timestamp;
    uint96 nonce;
    uint256 numericValue; 
    bytes extraData;
}

struct SignedNumericData { 
    bytes signature;
    NumericData numericData;
}

struct UpshotOracleNumericData {
    SignedNumericData[] signedNumericData;
    bytes extraData;
}

struct FeedConfig {
    string title;
    address owner;
    uint96 nonce;
    uint256 totalFee;
    IAggregator aggregator;
    bool ownerSwitchedOn;
    bool adminSwitchedOn;
    IFeeHandler feeHandler;
    uint48 dataProviderQuorum;
    uint48 dataValiditySeconds;
}

/// @dev The struct for a feed, using a set for valid data providers 
struct Feed { 
    FeedConfig config;
    EnumerableSet.AddressSet validDataProviders;
}

// TODO reduce data structure size
/// @dev The struct for viewing a feed, which can be loaded into memory and returned
struct FeedView { 
    FeedConfig config;
    address[] validDataProviders;
}

// ***************************************************************
// * ======================= INTERFACE ========================= *
// ***************************************************************

/**
 * @title Oracle Interface
 */
interface IOracle {

    /**
     * @notice Get an verified piece of numeric data for a given feed
     * 
     * @param pd The numeric data to aggregate
     */
    function verifyData(UpshotOracleNumericData calldata pd) external payable returns (uint256 numericValue);
}
