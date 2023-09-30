// SPDX-License-Identifier: BUSL-1.1

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

struct Feed { 
    string title;
    bool isValid;
    uint256 nonce;
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
