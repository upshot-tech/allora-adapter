// SPDX-License-Identifier: BUSL-1.1

import { IAggregator } from '../interface/IAggregator.sol';
import { IFeeHandler } from '../interface/IFeeHandler.sol';
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


pragma solidity ^0.8.0;

// ***************************************************************
// * ========================= STRUCTS ========================= *
// ***************************************************************

struct PriceData { 
    bytes signature;
    uint256 feedId;
    uint256 nonce;
    uint96 timestamp;
    uint256 price; 
    bytes extraData;
}

/// @dev The struct for a feed, using a set for valid price providers 
struct Feed { 
    string title;
    uint256 nonce;
    uint256 totalFee;
    uint256 minPrices;
    uint256 priceValiditySeconds;
    IAggregator aggregator;
    bool isValid;
    IFeeHandler feeHandler;
    EnumerableSet.AddressSet validPriceProviders;
}

// TODO reduce data structure size
/// @dev The struct for viewing a feed, which can be loaded into memory and returned
struct FeedView { 
    string title;
    uint256 nonce;
    uint256 totalFee;
    uint256 minPrices;
    uint256 priceValiditySeconds;
    IAggregator aggregator;
    bool isValid;
    IFeeHandler feeHandler;
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
     * @param priceData The price data to aggregate
     */
    function getPrice(
        PriceData[] calldata priceData,
        bytes calldata extraData
    ) external payable returns (uint256 price);
}
