// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IAggregator } from './interface/IAggregator.sol';
import { PriceData } from './interface/IPrices.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";


contract Prices {

    uint256 public minPrices = 1;

    uint256 public priceValiditySeconds = 5 minutes;

    mapping(address signer => bool isValid) public validSigner;

    mapping(uint256 feedId => uint256 nonce) public feedNonce;

    IAggregator aggregator;

    uint256 public priceFee = 0.001 ether;

    uint256 public protocolFeePortion = 0.1 ether;

    address public protocolFeeReceiver;

    constructor(
        address _aggregator,
        address _protocolFeeReceiver
    ) {
        aggregator = IAggregator(_aggregator);
        protocolFeeReceiver = _protocolFeeReceiver;
    }

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************
    event UpshotOracleAdminSetAuthenticator(address authenticator);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************
    error UpshotOracleInvalidPriceTime();
    error UpshotOracleInvalidSigner();
    error UpshotOracleDuplicateSigner();
    error UpshotOracleNotEnoughPrices();
    error UpshotOracleFeedMismatch();
    error UpshotOracleInvalidNonce();
    error UpshotOracleNonceMismatch();
    error UpshotOracleInsufficientPayment();
    error UpshotOracleEthTransferFailed();


    function getPrice(
        PriceData[] calldata priceData
    ) external payable returns (uint256 price) {
        if (msg.value < priceFee) {
            revert UpshotOracleInsufficientPayment();
        }

        uint256 priceDataCount = priceData.length;

        if (priceDataCount < minPrices) {
            revert UpshotOracleNotEnoughPrices();
        }

        uint256[] memory tokenPrices = new uint256[](priceDataCount);
        address[] memory priceProviders = new address[](priceDataCount);
        uint256 feedId = priceData[0].feedId;
        uint256 nonce = priceData[0].feedId;

        _validateNonce(feedId, nonce);

        PriceData memory data;
        for(uint256 i = 0; i < priceDataCount;) {
            data = priceData[i];

            if (data.feedId != feedId) {
                revert UpshotOracleFeedMismatch();
            }

            if (data.nonce != nonce) {
                revert UpshotOracleNonceMismatch();
            }

            if (
                block.timestamp < data.timestamp ||
                data.timestamp + priceValiditySeconds < block.timestamp 
            ) {
                revert UpshotOracleInvalidPriceTime();
            }

            address signer =
                ECDSA.recover(
                    ECDSA.toEthSignedMessageHash(getPriceMessage(
                        data.feedId,
                        data.nonce,
                        data.timestamp, 
                        data.price, 
                        data.extraData
                    )),
                    data.signature
                );

            if (!validSigner[signer]) {
                revert UpshotOracleInvalidSigner();
            }

            for (uint256 j = 0; j < i; i++) {
                if (signer == priceProviders[j]) {
                    revert UpshotOracleDuplicateSigner();
                }
            }

            priceProviders[i] = signer;

            tokenPrices[i] = data.price;

            unchecked {
                ++i;
            }
        }

        price = aggregator.aggregate(tokenPrices, "");

        _payFees(priceProviders);
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

    /**
     * @dev Update the nonce for the collection and revert if the nonce is invalid
     *
     * @param feedId The feedId to update the nonce for
     * @param nonce The new nonce
     */
    function _validateNonce(uint256 feedId, uint256 nonce) internal {
        if (nonce < feedNonce[feedId]) {
            revert UpshotOracleInvalidNonce();
        }

        feedNonce[feedId] = nonce;
    }

    function _payFees(address[] memory priceProviders) internal {
        uint256 protocolFee = Math.mulDiv(priceFee, protocolFeePortion, 1 ether);
        uint256 priceProviderFee = (priceFee - protocolFee) / priceProviders.length;

        _safeTransferETH(protocolFeeReceiver, protocolFee);

        for (uint i = 0; i < priceProviders.length; i++) {
            _safeTransferETH(priceProviders[i], priceProviderFee);
        }
    }

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) {
            revert UpshotOracleEthTransferFailed();
        }
    }
}
