// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IPrices, Feed } from './interface/IPrices.sol';
import { IAggregator } from './interface/IAggregator.sol';
import { IFeeHandler } from './interface/IFeeHandler.sol';
import { PriceData } from './interface/IPrices.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";


contract Prices is IPrices, Ownable2Step {

    /// @dev The minimum number of prices required to get a valid price
    uint256 public minPrices = 1;

    // @dev The number of seconds a price is valid for
    uint256 public priceValiditySeconds = 5 minutes;

    // @dev The valid signers
    mapping(address signer => bool isValid) public validSigner;

    // @dev The nonce for each feed
    mapping(uint256 feedId => Feed) public feed;

    // @dev The aggregator to use for aggregating prices
    IAggregator aggregator;

    // @dev The fee handler to use for handling fees
    IFeeHandler feeHandler;

    // @dev Whether the oracle contract is switched on and usable
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

    event UpshotOracleV2PricesGotPrice(uint256 feedId, uint256 price, address[] priceProviders, uint256 nonce);
    event UpshotOracleV2PricesFeedAdded(uint256 feedId, string title);
    event UpshotOracleV2PricesAdminUpdatedMinPrices(uint256 minPrices);
    event UpshotOracleV2PricesAdminUpdatedPriceValiditySeconds(uint256 priceValiditySeconds);
    event UpshotOracleV2PricesAdminAddedValidSigner(address signer);
    event UpshotOracleV2PricesAdminRemovedValidSigner(address signer);
    event UpshotOracleV2PricesAdminAddedFeed(uint256 feedId, string title);
    event UpshotOracleV2PricesAdminRemovedFeed(uint256 feedId);
    event UpshotOracleV2PricesAdminUpdatedAggregator(address aggregator);
    event UpshotOracleV2PricesAdminSwitchedOff();
    event UpshotOracleV2PricesAdminSwitchedOn();

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

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************

    ///@inheritdoc IPrices
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

        if (priceDataCount == 0 || priceDataCount < minPrices) {
            revert UpshotOracleNotEnoughPrices();
        }

        uint256[] memory tokenPrices = new uint256[](priceDataCount);
        address[] memory priceProviders = new address[](priceDataCount);
        uint256 feedId = priceData[0].feedId;
        uint256 nonce = priceData[0].nonce;

        if (!feed[feedId].isValid) {
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

            // add a statement that the nonce is nonce + 1

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

        emit UpshotOracleV2PricesGotPrice(feedId, price, priceProviders, nonce);
    }

    /**
     * @notice The message that must be signed by the signer to provide a valid price 
     *   recognized by getPrice
     * 
     * @param feedId The feedId to get the price for
     * @param nonce The nonce for the feed
     * @param timestamp The timestamp for the price
     * @param price The price
     * @param extraData Any extra data to be used by the price provider
     */
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
        if (nonce != feed[feedId].nonce + 1) {
            revert UpshotOracleInvalidNonce();
        }

        feed[feedId].nonce = nonce;
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************
    function updateMinPrices(uint256 minPrices_) external onlyOwner {
        if (minPrices_ > 0) {
            minPrices = minPrices_;
        }

        emit UpshotOracleV2PricesAdminUpdatedMinPrices(minPrices_);
    }

    function updatePriceValiditySeconds(uint256 priceValiditySeconds_) external onlyOwner {
        if (priceValiditySeconds_ > 0) {
            priceValiditySeconds = priceValiditySeconds_;
        }

        emit UpshotOracleV2PricesAdminUpdatedPriceValiditySeconds(priceValiditySeconds_);
    }

    function addValidSigner(address signer) external onlyOwner {
        validSigner[signer] = true;

        emit UpshotOracleV2PricesAdminAddedValidSigner(signer);
    }

    function removeValidSigner(address signer) external onlyOwner {
        validSigner[signer] = false;

        emit UpshotOracleV2PricesAdminRemovedValidSigner(signer);
    }

    function addFeed(uint256 feedId, string memory title) external onlyOwner {
        if (bytes(title).length > 0) {
            feed[feedId] = Feed({
                title: title,
                isValid: true,
                nonce: 1
            });
        }

        emit UpshotOracleV2PricesAdminAddedFeed(feedId, title);
    }

    function removeFeed(uint256 feedId) external onlyOwner {
        delete feed[feedId];
        
        emit UpshotOracleV2PricesAdminRemovedFeed(feedId);
    }

    function updateAggregator(address aggregator_) external onlyOwner {
        aggregator = IAggregator(aggregator_);

        emit UpshotOracleV2PricesAdminUpdatedAggregator(aggregator_);
    }

    function turnOff() external onlyOwner {
        switchedOn = false;

        emit UpshotOracleV2PricesAdminSwitchedOff();
    }

    function turnOn() external onlyOwner {
        switchedOn = true;

        emit UpshotOracleV2PricesAdminSwitchedOn();
    }
}
