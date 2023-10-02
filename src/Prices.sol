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

    /// @dev The number of seconds a price is valid for
    uint256 public priceValiditySeconds = 5 minutes;

    /// @dev The valid signers
    mapping(address signer => bool isValid) public validSigner;

    /// @dev The nonce for each feed
    mapping(uint256 feedId => Feed) public feed;

    /// @dev The next feedId to use
    uint256 public nextFeedId = 1;

    /// @dev The aggregator to use for aggregating prices
    IAggregator aggregator;

    /// @dev The fee handler to use for handling fees
    IFeeHandler feeHandler;

    /// @dev Whether the oracle contract is switched on and usable
    bool public switchedOn = true;

    /// @dev The total fee to be paid by the user
    uint256 public feePerPrice = 0.001 ether;


    constructor(
        address admin_,
        address aggregator_,
        address feeHandler_
    ) {
        _transferOwnership(admin_);

        aggregator = IAggregator(aggregator_);
        emit UpshotOracleV2PricesAdminUpdatedAggregator(aggregator_);

        feeHandler = IFeeHandler(feeHandler_);
            emit UpshotOracleV2PricesAdminUpdatedFeeHandler(feeHandler_);
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
    event UpshotOracleV2PricesAdminUpdatedFeeHandler(address feeHandler);
    event UpshotOracleV2PricesAdminSwitchedOff();
    event UpshotOracleV2PricesAdminSwitchedOn();
    event UpshotOracleV2AdminUpdatedFeePerPrice(uint256 feePerPrice);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error UpshotOracleV2InvalidPriceTime();
    error UpshotOracleV2InvalidSigner();
    error UpshotOracleV2DuplicateSigner();
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
        PriceData[] calldata priceData,
        bytes calldata
    ) external payable override returns (uint256 price) {
        if (!switchedOn) {
            revert UpshotOracleV2NotSwitchedOn();
        }

        if (msg.value < feePerPrice) {
            revert UpshotOracleV2InsufficientPayment();
        }

        uint256 priceDataCount = priceData.length;

        if (priceDataCount == 0 || priceDataCount < minPrices) {
            revert UpshotOracleV2NotEnoughPrices();
        }

        uint256[] memory tokenPrices = new uint256[](priceDataCount);
        address[] memory priceProviders = new address[](priceDataCount);
        uint256 feedId = priceData[0].feedId;
        uint256 nonce = priceData[0].nonce;

        if (!feed[feedId].isValid) {
            revert UpshotOracleV2InvalidFeed();
        }

        _validateNonce(feedId, nonce);

        PriceData memory data;
        for(uint256 i = 0; i < priceDataCount;) {
            data = priceData[i];

            if (data.feedId != feedId) {
                revert UpshotOracleV2FeedMismatch();
            }

            if (data.nonce != nonce) {
                revert UpshotOracleV2NonceMismatch();
            }

            if (
                block.timestamp < data.timestamp ||
                data.timestamp + priceValiditySeconds < block.timestamp
            ) {
                revert UpshotOracleV2InvalidPriceTime();
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
                revert UpshotOracleV2InvalidSigner();
            }

            for (uint256 j = 0; j < i; j++) {
                if (signer == priceProviders[j]) {
                    revert UpshotOracleV2DuplicateSigner();
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
     * @param minPrices_ The minimum number of prices required to get a valid price
     */
    function updateMinPrices(uint256 minPrices_) external onlyOwner {
        if (minPrices_ == 0) {
            revert UpshotOracleV2PricesInvalidMinPrices();
        }

        minPrices = minPrices_;

        emit UpshotOracleV2PricesAdminUpdatedMinPrices(minPrices_);
    }

    /**
     * @notice Admin function to update the number of seconds a price is valid for
     * 
     * @param priceValiditySeconds_ The number of seconds a price is valid for
     */
    function updatePriceValiditySeconds(uint256 priceValiditySeconds_) external onlyOwner {
        if (priceValiditySeconds == 0) { 
            revert UpshotOracleV2InvalidPriceValiditySeconds();
        }

        priceValiditySeconds = priceValiditySeconds_;

        emit UpshotOracleV2PricesAdminUpdatedPriceValiditySeconds(priceValiditySeconds_);
    }

    /**
     * @notice Admin function to add a valid signer
     * 
     * @param signer The signer to add
     */
    function addValidSigner(address signer) external onlyOwner {
        validSigner[signer] = true;

        emit UpshotOracleV2PricesAdminAddedValidSigner(signer);
    }

    /**
     * @notice Admin function to remove a valid signer
     * 
     * @param signer The signer to remove
     */
    function removeValidSigner(address signer) external onlyOwner {
        validSigner[signer] = false;

        emit UpshotOracleV2PricesAdminRemovedValidSigner(signer);
    }

    /**
     * @notice Admin function to add a feed
     * 
     * @param title The title of the feed
     */
    function addFeed(string memory title) external onlyOwner {
        if (bytes(title).length == 0) {
            revert UpshotOracleV2InvalidFeedTitle();
        }

        feed[nextFeedId] = Feed({
            title: title,
            isValid: true,
            nonce: 1
        });

        emit UpshotOracleV2PricesAdminAddedFeed(nextFeedId, title);

        unchecked { ++nextFeedId; }
    }

    /**
     * @notice Admin function to remove a feed
     * 
     * @param feedId The feedId of the feed to remove
     */
    function removeFeed(uint256 feedId) external onlyOwner {
        delete feed[feedId];
        
        emit UpshotOracleV2PricesAdminRemovedFeed(feedId);
    }

    /**
     * @notice Admin function to update the aggregator to use for aggregating prices
     * 
     * @param aggregator_ The aggregator to use for aggregating prices
     */
    function updateAggregator(address aggregator_) external onlyOwner {
        if (aggregator_ == address(0)) {
            revert UpshotOracleV2InvalidAggregator();
        }

        aggregator = IAggregator(aggregator_);

        emit UpshotOracleV2PricesAdminUpdatedAggregator(aggregator_);
    }

    /**
     * @notice Admin function to update the fee handler to use for handling fees
     * 
     * @param feeHandler_ The fee handler to use for handling fees
     */
    function updateFeeHandler(address feeHandler_) external onlyOwner {
        if (feeHandler_ == address(0)) {
            revert UpshotOracleV2InvalidFeeHandler();
        }

        feeHandler = IFeeHandler(feeHandler_);

        emit UpshotOracleV2PricesAdminUpdatedFeeHandler(feeHandler_);
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
     * @param feePerPrice_ The total fee to be paid per price
     */
    function updateTotalFee(uint256 feePerPrice_) external onlyOwner {
        if (0 < feePerPrice_ && feePerPrice_ < 1_000) {
            revert UpshotOracleV2InvalidTotalFee();
        }
        feePerPrice = feePerPrice_;

        emit UpshotOracleV2AdminUpdatedFeePerPrice(feePerPrice_);
    }
}
