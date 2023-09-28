// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IAggregator } from './interface/IAggregator.sol';
import { PriceData } from './interface/IPrices.sol';
import { ECDSA } from "./openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract Prices {

    uint256 public minPrices = 2;

    uint256 public priceValiditySeconds = 5 minutes;


    function getPrice(
        PriceData[] calldata priceData
    ) external payable returns (uint256 price) {
        uint256 priceDataCount = priceData.length;
        uint256[] memory tokenPrices = new uint256[](priceDataCount);

        PriceData memory data;
        for(uint256 i = 0; i < priceDataCount;) {
            data = priceData[i];

            if (
                block.timestamp < data.timestamp ||
                data.expiration < block.timestamp 
            ) {
                revert UpshotOracleInvalidPriceTime();
            }

            address signer =
                ECDSA.recover(
                    ECDSA.toEthSignedMessageHash(getPriceMessage(
                        data.nonce,
                        data.nft, 
                        data.nftId, 
                        data.token, 
                        data.price, 
                        data.timestamp,
                        data.expiration,
                        data.extraData
                    )),
                    data.signature
                );

            if (signer != _authenticator) {
                revert UpshotOracleInvalidSigner();
            }

            _validateNonce(data.nft, data.nonce);

            tokenPrices[i] = data.price;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice  
    function getPriceMessage(
        uint256 feedId,
        uint256 nonce,
        uint96 timestamp,
        uint256 price,
        bytes memory extraData
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(
            block.chainid, 
            feedId,
            nonce,
            timestamp,
            price, 
            extraData
        ));
    }
}
