// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IPrices, Feed, FeedView } from './interface/IPrices.sol';
import { IAggregator } from './interface/IAggregator.sol';
import { IFeeHandler } from './interface/IFeeHandler.sol';
import { SignedPriceData, PriceData } from './interface/IPrices.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

struct PricesConstructorArgs {
    address admin;
}

contract Prices is IPrices, Ownable2Step {

    /// @dev The data for each feed. Call getFeed function for access to structured data
    mapping(uint256 feedId => Feed) internal feed;

    /// @dev The next feedId to use
    uint256 public nextFeedId = 1;

    /// @dev Whether the oracle contract is switched on and usable
    bool public switchedOn = true;

    constructor(
        PricesConstructorArgs memory args
    ) {
        _transferOwnership(args.admin);
    }

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    event UpshotOracleV2PricesGotPrice(uint256 feedId, uint256 price, address[] priceProviders, uint128 nonce);
    event UpshotOracleV2PricesAdminUpdatedMinPrices(uint256 feedId, uint48 minPrices);
    event UpshotOracleV2PricesAdminUpdatedPriceValiditySeconds(uint256 feedId, uint48 priceValiditySeconds);
    event UpshotOracleV2PricesAdminAddedValidSigner(uint256 feedId, address signer);
    event UpshotOracleV2PricesAdminRemovedValidSigner(address signer);
    event UpshotOracleV2PricesAdminAddedFeed(FeedView feedView);
    event UpshotOracleV2PricesAdminFeedTurnedOff(uint256 feedId);
    event UpshotOracleV2PricesAdminFeedTurnedOn(uint256 feedId);
    event UpshotOracleV2PricesAdminUpdatedAggregator(uint256 feedId, IAggregator aggregator);
    event UpshotOracleV2PricesAdminUpdatedFeeHandler(uint256 feedId, IFeeHandler feeHandler);
    event UpshotOracleV2PricesAdminSwitchedOff();
    event UpshotOracleV2PricesAdminSwitchedOn();
    event UpshotOracleV2AdminUpdatedFeePerPrice(uint128 totalFee);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error UpshotOracleV2InvalidPriceTime();
    error UpshotOracleV2InvalidSigner();
    error UpshotOracleV2DuplicateSigner();
    error UpshotOracleV2NoPricesProvided();
    error UpshotOracleV2NotEnoughPrices();
    error UpshotOracleV2FeedMismatch();
    error UpshotOracleV2InvalidFeed();
    error UpshotOracleV2InvalidNonce();
    error UpshotOracleV2NonceMismatch();
    error UpshotOracleV2InsufficientPayment();
    error UpshotOracleV2NotSwitchedOn();
    error UpshotOracleV2InvalidTotalFee();
    error UpshotOracleV2InvalidFeeHandler();
    error UpshotOracleV2InvalidAggregator();
    error UpshotOracleV2PricesInvalidMinPrices();
    error UpshotOracleV2InvalidPriceValiditySeconds();
    error UpshotOracleV2InvalidFeedTitle();

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************

    ///@inheritdoc IPrices
    function getPrice(
        SignedPriceData[] calldata signedPriceData,
        bytes calldata
    ) external payable override returns (uint256 price) {
        if (!switchedOn) {
            revert UpshotOracleV2NotSwitchedOn();
        }

        uint256 priceDataCount = signedPriceData.length;

        if (priceDataCount == 0) {
            revert UpshotOracleV2NoPricesProvided();
        }

        uint256 feedId = signedPriceData[0].priceData.feedId;

        if (!feed[feedId].isValid) {
            revert UpshotOracleV2InvalidFeed();
        }

        if (msg.value < feed[feedId].totalFee) {
            revert UpshotOracleV2InsufficientPayment();
        }

        if (priceDataCount < feed[feedId].minPrices) {
            revert UpshotOracleV2NotEnoughPrices();
        }

        uint128 nonce = signedPriceData[0].priceData.nonce;
        _validateNonce(feedId, nonce);

        uint256[] memory prices = new uint256[](priceDataCount);
        address[] memory priceProviders = new address[](priceDataCount);
        PriceData calldata priceData;

        for(uint256 i = 0; i < priceDataCount;) {
            priceData = signedPriceData[i].priceData;

            if (priceData.feedId != feedId) {
                revert UpshotOracleV2FeedMismatch();
            }

            if (priceData.nonce != nonce) {
                revert UpshotOracleV2NonceMismatch();
            }

            if (
                block.timestamp < priceData.timestamp ||
                priceData.timestamp + feed[feedId].priceValiditySeconds < block.timestamp
            ) {
                revert UpshotOracleV2InvalidPriceTime();
            }

            address priceSigner =
                ECDSA.recover(
                    ECDSA.toEthSignedMessageHash(getPriceMessage(priceData)),
                    signedPriceData[i].signature
                );

            if (!EnumerableSet.contains(feed[feedId].validPriceProviders, priceSigner)) {
                revert UpshotOracleV2InvalidSigner();
            }

            for (uint256 j = 0; j < i;) {
                if (priceSigner == priceProviders[j]) {
                    revert UpshotOracleV2DuplicateSigner();
                }

                unchecked { 
                    ++j; 
                }
            }

            priceProviders[i] = priceSigner;

            prices[i] = priceData.price;

            unchecked {
                ++i;
            }
        }

        price = feed[feedId].aggregator.aggregate(prices, '');

        feed[feedId].feeHandler.handleFees{value: msg.value}(priceProviders, '');

        emit UpshotOracleV2PricesGotPrice(feedId, price, priceProviders, nonce);
    }

    /**
     * @notice The message that must be signed by the signer to provide a valid price 
     *   recognized by getPrice
     * 
     * @param priceData The priceData
     */
    function getPriceMessage(
        PriceData calldata priceData
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(
            block.chainid, 
            priceData.feedId,
            priceData.nonce,
            priceData.timestamp,
            priceData.price, 
            priceData.extraData
        ));
    }

    // ***************************************************************
    // * ===================== VIEW FUNCTIONS ====================== *
    // ***************************************************************
    /**
     * @notice Get the feed data for a given feedId
     * 
     * @return  feedView The feed data
     */
    function getFeed(uint256 feedId) external view returns (FeedView memory feedView) {
        feedView = FeedView({
            title: feed[feedId].title,
            nonce: feed[feedId].nonce,
            totalFee: feed[feedId].totalFee,
            minPrices: feed[feedId].minPrices,
            priceValiditySeconds: feed[feedId].priceValiditySeconds,
            aggregator: feed[feedId].aggregator,
            isValid: feed[feedId].isValid,
            feeHandler: feed[feedId].feeHandler,
            validPriceProviders: EnumerableSet.values(feed[feedId].validPriceProviders)
        });
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
    function _validateNonce(uint256 feedId, uint128 nonce) internal {
        if (nonce != feed[feedId].nonce + 1) {
            revert UpshotOracleV2InvalidNonce();
        }

        feed[feedId].nonce = nonce;
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Admin function to update the minimum number of prices required to get a valid price
     * 
     * @param feedId The feedId to update the minimum number of prices for
     * @param minPrices The minimum number of prices required to get a valid price
     */
    function updateMinPrices(uint256 feedId, uint48 minPrices) external onlyOwner {
        if (minPrices == 0) {
            revert UpshotOracleV2PricesInvalidMinPrices();
        }

        feed[feedId].minPrices = minPrices;

        emit UpshotOracleV2PricesAdminUpdatedMinPrices(feedId, minPrices);
    }

    /**
     * @notice Admin function to update the number of seconds a price is valid for
     * 
     * @param feedId The feedId to update the number of seconds a price is valid for
     * @param priceValiditySeconds The number of seconds a price is valid for
     */
    function updatePriceValiditySeconds(uint256 feedId, uint48 priceValiditySeconds) external onlyOwner {
        if (priceValiditySeconds == 0) { 
            revert UpshotOracleV2InvalidPriceValiditySeconds();
        }

        feed[feedId].priceValiditySeconds = priceValiditySeconds;

        emit UpshotOracleV2PricesAdminUpdatedPriceValiditySeconds(feedId, priceValiditySeconds);
    }

    /**
     * @notice Admin function to add a valid signer
     * 
     * @param feedId The feedId to add the valid signer for
     * @param signer The signer to add
     */
    function addValidSigner(uint256 feedId, address signer) external onlyOwner {
        EnumerableSet.add(feed[feedId].validPriceProviders, signer);

        emit UpshotOracleV2PricesAdminAddedValidSigner(feedId, signer);
    }

    /**
     * @notice Admin function to remove a valid signer
     * 
     * @param feedId The feedId to remove the signer from
     * @param signer The signer to remove
     */
    function removeValidSigner(uint256 feedId, address signer) external onlyOwner {
        EnumerableSet.remove(feed[feedId].validPriceProviders, signer);

        emit UpshotOracleV2PricesAdminRemovedValidSigner(signer);
    }

    /**
     * @notice Admin function to add a new feed
     * 
     */
    function addFeed(
        FeedView calldata feedView
    ) external onlyOwner returns (uint256 newFeedId) {
        if (bytes(feedView.title).length == 0) {
            revert UpshotOracleV2InvalidFeedTitle();
        }
        newFeedId = nextFeedId++;

        feed[newFeedId].title = feedView.title;
        feed[newFeedId].nonce = 1;
        feed[newFeedId].totalFee = feedView.totalFee;
        feed[newFeedId].minPrices = feedView.minPrices;
        feed[newFeedId].priceValiditySeconds = feedView.priceValiditySeconds;
        feed[newFeedId].aggregator = feedView.aggregator;
        feed[newFeedId].isValid = true;
        feed[newFeedId].feeHandler = feedView.feeHandler;

        for (uint256 i = 0; i < feedView.validPriceProviders.length;) {
            EnumerableSet.add(feed[newFeedId].validPriceProviders, feedView.validPriceProviders[i]);

            unchecked {
                ++i;
            }
        }

        emit UpshotOracleV2PricesAdminAddedFeed(feedView);
    }

    /**
     * @notice Admin function to turn off a feed
     * 
     * @param feedId The feedId of the feed to turn off
     */
    function turnOffFeed(uint256 feedId) external onlyOwner {
        feed[feedId].isValid = false;
        
        emit UpshotOracleV2PricesAdminFeedTurnedOff(feedId);
    }

    /**
     * @notice Admin function to turn on a feed
     * 
     * @param feedId The feedId of the feed to turn on
     */
    function turnOnFeed(uint256 feedId) external onlyOwner {
        feed[feedId].isValid = true;
        
        emit UpshotOracleV2PricesAdminFeedTurnedOn(feedId);
    }

    /**
     * @notice Admin function to update the aggregator to use for aggregating prices
     * 
     * @param aggregator The aggregator to use for aggregating prices
     */
    function updateAggregator(uint256 feedId, IAggregator aggregator) external onlyOwner {
        if (address(aggregator) == address(0)) {
            revert UpshotOracleV2InvalidAggregator();
        }

        feed[feedId].aggregator = aggregator;

        emit UpshotOracleV2PricesAdminUpdatedAggregator(feedId, aggregator);
    }

    /**
     * @notice Admin function to update the fee handler to use for handling fees
     * 
     * @param feeHandler The fee handler to use for handling fees
     */
    function updateFeeHandler(uint256 feedId, IFeeHandler feeHandler) external onlyOwner {
        if (address(feeHandler) == address(0)) {
            revert UpshotOracleV2InvalidFeeHandler();
        }

        feed[feedId].feeHandler = feeHandler;

        emit UpshotOracleV2PricesAdminUpdatedFeeHandler(feedId, feeHandler);
    } 

    /**
     * @notice Admin function to switch off the oracle contract
     */
    function turnOff() external onlyOwner {
        switchedOn = false;

        emit UpshotOracleV2PricesAdminSwitchedOff();
    }

    /**
     * @notice Admin function to switch on the oracle contract
     */
    function turnOn() external onlyOwner {
        switchedOn = true;

        emit UpshotOracleV2PricesAdminSwitchedOn();
    }

    /**
     * @notice Admin function to update the total fee to be paid per price
     * 
     * @param feedId The feedId to update the total fee for
     * @param totalFee The total fee to be paid per price
     */
    function updateTotalFee(uint256 feedId, uint128 totalFee) external onlyOwner {
        if (0 < totalFee && totalFee < 1_000) {
            revert UpshotOracleV2InvalidTotalFee();
        }
        feed[feedId].totalFee = totalFee;

        emit UpshotOracleV2AdminUpdatedFeePerPrice(totalFee);
    }
}
