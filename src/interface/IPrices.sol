// SPDX-License-Identifier: BUSL-1.1

import { IAggregator } from '../interface/IAggregator.sol';
import { IFeeHandler } from '../interface/IFeeHandler.sol';
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


pragma solidity ^0.8.0;

// ***************************************************************
// * ========================= STRUCTS ========================= *
// ***************************************************************

struct PriceData {
    uint64 feedId;
    uint64 timestamp;
    uint128 nonce;
    uint256 price; 
    bytes extraData;
}

struct SignedPriceData { 
    bytes signature;
    PriceData priceData;
}

struct UpshotOraclePriceData {
    SignedPriceData[] signedPriceData;
    bytes extraData;
}

/// @dev The struct for a feed, using a set for valid price providers 
struct Feed { 
    string title;
    uint128 nonce;
    uint128 totalFee;
    IAggregator aggregator;
    bool isValid;
    IFeeHandler feeHandler;
    uint48 minPrices;
    uint48 priceValiditySeconds;
    EnumerableSet.AddressSet validPriceProviders;
}

// TODO reduce data structure size
/// @dev The struct for viewing a feed, which can be loaded into memory and returned
struct FeedView { 
    string title;
    uint128 nonce;
    uint128 totalFee;
    IAggregator aggregator;
    bool isValid;
    IFeeHandler feeHandler;
    uint48 minPrices;
    uint48 priceValiditySeconds;
    address[] validPriceProviders;
}

// ***************************************************************
// * ======================= INTERFACE ========================= *
// ***************************************************************

/**
 * @title Prices Interface
 */
interface IPrices {

    /**
     * @notice Get an aggregated price for a given feed
     * 
     * @param pd The price data to aggregate
     */
    function getPrice(UpshotOraclePriceData calldata pd) external payable returns (uint256 price);
}
