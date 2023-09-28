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

/**
 * @title Prices Interface
 */
interface IPrices {
    function getPrice(
        PriceData[] calldata priceData,
        bytes calldata extraData
    ) external payable returns (uint256 price);
}
