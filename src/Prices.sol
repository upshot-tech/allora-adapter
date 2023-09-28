// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IPrices } from './interface/IPrices.sol';
import { IAggregator } from './interface/IAggregator.sol';
import { IFeeHandler } from './interface/IFeeHandler.sol';
import { PriceData } from './interface/IPrices.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";


contract Prices is IPrices, Ownable2Step {

    uint256 public minPrices = 1;

    uint256 public priceValiditySeconds = 5 minutes;

    mapping(address signer => bool isValid) public validSigner;

    mapping(uint256 feedId => uint256 nonce) public feedNonce;

    mapping(uint256 feedId => string title) public feed;

    IAggregator aggregator;

    IFeeHandler feeHandler;

    bool public switchedOn = true;


    constructor(
        address _admin,
        address _aggregator,
        address _feeHandler
    ) {
        _transferOwnership(_admin);

        aggregator = IAggregator(_aggregator);
        feeHandler = IFeeHandler(_feeHandler);
    }

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************
    // TODO

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************
    error UpshotOracleInvalidPriceTime();
    error UpshotOracleInvalidSigner();
    error UpshotOracleDuplicateSigner();
    error UpshotOracleNotEnoughPrices();
    error UpshotOracleFeedMismatch();
    error UpshotOracleInvalidFeed();
    error UpshotOracleInvalidNonce();
    error UpshotOracleNonceMismatch();
    error UpshotOracleInsufficientPayment();
    error UpshotOracleNotSwitchedOn();


    function getPrice(
        PriceData[] calldata priceData,
        bytes calldata
    ) external payable override returns (uint256 price) {
        if (!switchedOn) {
            revert UpshotOracleNotSwitchedOn();
        }

        if (msg.value < feeHandler.totalFee()) {
            revert UpshotOracleInsufficientPayment();
        }

        uint256 priceDataCount = priceData.length;

        if (priceDataCount < minPrices) {
            revert UpshotOracleNotEnoughPrices();
        }

        uint256[] memory tokenPrices = new uint256[](priceDataCount);
        address[] memory priceProviders = new address[](priceDataCount);
        uint256 feedId = priceData[0].feedId;
        uint256 nonce = priceData[0].nonce;

        if (bytes(feed[feedId]).length == 0) {
            revert UpshotOracleInvalidFeed();
        }

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

            for (uint256 j = 0; j < i; j++) {
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

        feeHandler.handleFees{value: msg.value}(priceProviders, "");
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

    // ***************************************************************
    // * ==================== INTERNAL HELPERS ===================== *
    // ***************************************************************
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

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************
    function updateMinPrices(uint256 minPrices_) external onlyOwner {
        if (minPrices_ > 0) {
            minPrices = minPrices_;
        }
    }

    function updatePriceValiditySeconds(uint256 priceValiditySeconds_) external onlyOwner {
        if (priceValiditySeconds_ > 0) {
            priceValiditySeconds = priceValiditySeconds_;
        }
    }

    function addValidSigner(address signer) external onlyOwner {
        validSigner[signer] = true;
    }

    function removeValidSigner(address signer) external onlyOwner {
        validSigner[signer] = false;
    }

    function addFeed(uint256 feedId, string memory title) external onlyOwner {
        if (bytes(title).length > 0) {
            feed[feedId] = title;
        }
    }

    function removeFeed(uint256 feedId) external onlyOwner {
        delete feed[feedId];
    }

    function updateAggregator(address aggregator_) external onlyOwner {
        aggregator = IAggregator(aggregator_);
    }

    function turnOff() external onlyOwner {
        switchedOn = false;
    }

    function turnOn() external onlyOwner {
        switchedOn = true;
    }
}
