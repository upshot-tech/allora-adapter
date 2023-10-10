// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;


import { IAggregator } from './interface/IAggregator.sol';
import { IFeeHandler } from './interface/IFeeHandler.sol';
import { UpshotOracleNumericData, NumericData, IOracle, Feed, FeedView } from './interface/IOracle.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

struct OracleConstructorArgs {
    address admin;
}

contract Oracle is IOracle, Ownable2Step {

    /// @dev The data for each feed. Call getFeed function for access to structured data
    mapping(uint256 feedId => Feed) internal feed;

    /// @dev The next feedId to use
    uint256 public nextFeedId = 1;

    /// @dev Whether the oracle contract is switched on and usable
    bool public switchedOn = true;

    constructor(
        OracleConstructorArgs memory args
    ) {
        _transferOwnership(args.admin);
    }

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    event UpshotOracleV2OracleVerifiedData(uint256 feedId, uint256 numericData, address[] dataProviders, uint128 nonce);
    event UpshotOracleV2OracleAdminUpdatedDataProviderQuorum(uint256 feedId, uint48 dataProviderQuorum);
    event UpshotOracleV2OracleAdminUpdatedDataValiditySeconds(uint256 feedId, uint48 dataValiditySeconds);
    event UpshotOracleV2OracleAdminAddedDataProvider(uint256 feedId, address dataProvider);
    event UpshotOracleV2OracleAdminRemovedDataProvider(address dataProvider);
    event UpshotOracleV2OracleAdminAddedFeed(FeedView feedView);
    event UpshotOracleV2OracleAdminFeedTurnedOff(uint256 feedId);
    event UpshotOracleV2OracleAdminFeedTurnedOn(uint256 feedId);
    event UpshotOracleV2OracleAdminUpdatedAggregator(uint256 feedId, IAggregator aggregator);
    event UpshotOracleV2OracleAdminUpdatedFeeHandler(uint256 feedId, IFeeHandler feeHandler);
    event UpshotOracleV2OracleAdminSwitchedOff();
    event UpshotOracleV2OracleAdminSwitchedOn();
    event UpshotOracleV2OracleAdminUpdatedFeePerDataVerification(uint128 totalFee);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error UpshotOracleV2InvalidDataTime();
    error UpshotOracleV2InvalidDataProvider();
    error UpshotOracleV2DuplicateDataProvider();
    error UpshotOracleV2NoDataProvided();
    error UpshotOracleV2NotEnoughData();
    error UpshotOracleV2FeedMismatch();
    error UpshotOracleV2InvalidFeed();
    error UpshotOracleV2InvalidNonce();
    error UpshotOracleV2NonceMismatch();
    error UpshotOracleV2InsufficientPayment();
    error UpshotOracleV2NotSwitchedOn();
    error UpshotOracleV2InvalidTotalFee();
    error UpshotOracleV2InvalidFeeHandler();
    error UpshotOracleV2InvalidAggregator();
    error UpshotOracleV2OracleInvalidDataProviderQuorum();
    error UpshotOracleV2InvalidDataValiditySeconds();
    error UpshotOracleV2InvalidFeedTitle();

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************
    ///@inheritdoc IOracle
    function verifyData(
        UpshotOracleNumericData calldata nd
    ) external payable override returns (uint256 numericValue) {
        if (!switchedOn) {
            revert UpshotOracleV2NotSwitchedOn();
        }

        uint256 dataCount = nd.signedNumericData.length;

        if (dataCount == 0) {
            revert UpshotOracleV2NoDataProvided();
        }

        uint256 feedId = nd.signedNumericData[0].numericData.feedId;

        if (!feed[feedId].isValid) {
            revert UpshotOracleV2InvalidFeed();
        }

        if (msg.value < feed[feedId].totalFee) {
            revert UpshotOracleV2InsufficientPayment();
        }

        if (dataCount < feed[feedId].dataProviderQuorum) {
            revert UpshotOracleV2NotEnoughData();
        }

        uint128 nonce = nd.signedNumericData[0].numericData.nonce;
        _validateNonce(feedId, nonce);

        uint256[] memory dataList = new uint256[](dataCount);
        address[] memory dataProviders = new address[](dataCount);
        NumericData calldata numericData;

        for(uint256 i = 0; i < dataCount;) {
            numericData = nd.signedNumericData[i].numericData;

            if (numericData.feedId != feedId) {
                revert UpshotOracleV2FeedMismatch();
            }

            if (numericData.nonce != nonce) {
                revert UpshotOracleV2NonceMismatch();
            }

            if (
                block.timestamp < numericData.timestamp ||
                numericData.timestamp + feed[feedId].dataValiditySeconds < block.timestamp
            ) {
                revert UpshotOracleV2InvalidDataTime();
            }

            address dataProvider =
                ECDSA.recover(
                    ECDSA.toEthSignedMessageHash(getMessage(numericData)),
                    nd.signedNumericData[i].signature
                );

            if (!EnumerableSet.contains(feed[feedId].validDataProviders, dataProvider)) {
                revert UpshotOracleV2InvalidDataProvider();
            }

            for (uint256 j = 0; j < i;) {
                if (dataProvider == dataProviders[j]) {
                    revert UpshotOracleV2DuplicateDataProvider();
                }

                unchecked { 
                    ++j; 
                }
            }

            dataProviders[i] = dataProvider;

            dataList[i] = numericData.numericValue;

            unchecked {
                ++i;
            }
        }

        numericValue = feed[feedId].aggregator.aggregate(dataList, '');

        feed[feedId].feeHandler.handleFees{value: msg.value}(dataProviders, '');

        emit UpshotOracleV2OracleVerifiedData(feedId, numericValue, dataProviders, nonce);
    }

    /**
     * @notice The message that must be signed by the provider to provide valid data
     *   recognized by verifyData
     * 
     * @param numericData The numerical data to verify
     */
    function getMessage(
        NumericData calldata numericData
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(
            block.chainid, 
            numericData.feedId,
            numericData.nonce,
            numericData.timestamp,
            numericData.numericValue, 
            numericData.extraData
        ));
    }

    // ***************************************************************
    // * ===================== VIEW FUNCTIONS ====================== *
    // ***************************************************************
    /**
     * @notice Get the feed data for a given feedId
     * 
     * @param feedId The feedId to get the feed data for
     * @return feedView The feed data
     */
    function getFeed(uint256 feedId) external view returns (FeedView memory feedView) {
        feedView = FeedView({
            title: feed[feedId].title,
            nonce: feed[feedId].nonce,
            totalFee: feed[feedId].totalFee,
            dataProviderQuorum: feed[feedId].dataProviderQuorum,
            dataValiditySeconds: feed[feedId].dataValiditySeconds,
            aggregator: feed[feedId].aggregator,
            isValid: feed[feedId].isValid,
            feeHandler: feed[feedId].feeHandler,
            validDataProviders: EnumerableSet.values(feed[feedId].validDataProviders)
        });
    }

    // ***************************************************************
    // * ==================== INTERNAL HELPERS ===================== *
    // ***************************************************************
    /**
     * @dev Update the nonce for the collection and revert if the nonce is invalid
     *
     * @param feedId The feedId to validate and update the nonce for
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
     * @notice Admin function to update the minimum number of data providers needed to verify data
     * 
     * @param feedId The feedId to update the minimum number of data providers required
     * @param dataProviderQuorum The minimum number of data providers required
     */
    function updateDataProviderQuorum(uint256 feedId, uint48 dataProviderQuorum) external onlyOwner {
        if (dataProviderQuorum == 0) {
            revert UpshotOracleV2OracleInvalidDataProviderQuorum();
        }

        feed[feedId].dataProviderQuorum = dataProviderQuorum;

        emit UpshotOracleV2OracleAdminUpdatedDataProviderQuorum(feedId, dataProviderQuorum);
    }

    /**
     * @notice Admin function to update the number of seconds data is valid for
     * 
     * @param feedId The feedId to update the number of seconds data is valid for
     * @param dataValiditySeconds The number of seconds data is valid for
     */
    function updateDataValiditySeconds(uint256 feedId, uint48 dataValiditySeconds) external onlyOwner {
        if (dataValiditySeconds == 0) { 
            revert UpshotOracleV2InvalidDataValiditySeconds();
        }

        feed[feedId].dataValiditySeconds = dataValiditySeconds;

        emit UpshotOracleV2OracleAdminUpdatedDataValiditySeconds(feedId, dataValiditySeconds);
  }

  /**
     * @notice Admin function to add a data provider
     * 
     * @param feedId The feedId to add the data provider to
     * @param dataProvider The data provider to add
     */
    function addDataProvider(uint256 feedId, address dataProvider) external onlyOwner {
        EnumerableSet.add(feed[feedId].validDataProviders, dataProvider);

        emit UpshotOracleV2OracleAdminAddedDataProvider(feedId, dataProvider);
    }

    /**
     * @notice Admin function to remove a valid data provider
     * 
     * @param feedId The feedId to remove the data provider from
     * @param dataProvider the data provider to remove
     */
    function removeDataProvider(uint256 feedId, address dataProvider) external onlyOwner {
        EnumerableSet.remove(feed[feedId].validDataProviders, dataProvider);

        emit UpshotOracleV2OracleAdminRemovedDataProvider(dataProvider);
    }

    /**
     * @notice Admin function to add a new feed
     * 
     * @param feedView The feed data to add
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
        feed[newFeedId].dataProviderQuorum = feedView.dataProviderQuorum;
        feed[newFeedId].dataValiditySeconds = feedView.dataValiditySeconds;
        feed[newFeedId].aggregator = feedView.aggregator;
        feed[newFeedId].isValid = true;
        feed[newFeedId].feeHandler = feedView.feeHandler;

        for (uint256 i = 0; i < feedView.validDataProviders.length;) {
            EnumerableSet.add(feed[newFeedId].validDataProviders, feedView.validDataProviders[i]);

            unchecked {
                ++i;
            }
        }

        emit UpshotOracleV2OracleAdminAddedFeed(feedView);
    }

    /**
     * @notice Admin function to turn off a feed
     * 
     * @param feedId The feedId of the feed to turn off
     */
    function turnOffFeed(uint256 feedId) external onlyOwner {
        feed[feedId].isValid = false;
        
        emit UpshotOracleV2OracleAdminFeedTurnedOff(feedId);
    }

    /**
     * @notice Admin function to turn on a feed
     * 
     * @param feedId The feedId of the feed to turn on
     */
    function turnOnFeed(uint256 feedId) external onlyOwner {
        feed[feedId].isValid = true;
        
        emit UpshotOracleV2OracleAdminFeedTurnedOn(feedId);
    }

    /**
     * @notice Admin function to update the aggregator to use for aggregating numeric data
     * 
     * @param feedId The feedId to update the aggregator for
     * @param aggregator The aggregator to use for aggregating numeric data
     */
    function updateAggregator(uint256 feedId, IAggregator aggregator) external onlyOwner {
        if (address(aggregator) == address(0)) {
            revert UpshotOracleV2InvalidAggregator();
        }

        feed[feedId].aggregator = aggregator;

        emit UpshotOracleV2OracleAdminUpdatedAggregator(feedId, aggregator);
    }

    /**
     * @notice Admin function to update the fee handler to use for handling fees
     * 
     * @param feedId The feedId to update the fee handler for
     * @param feeHandler The fee handler to use for handling fees
     */
    function updateFeeHandler(uint256 feedId, IFeeHandler feeHandler) external onlyOwner {
        if (address(feeHandler) == address(0)) {
            revert UpshotOracleV2InvalidFeeHandler();
        }

        feed[feedId].feeHandler = feeHandler;

        emit UpshotOracleV2OracleAdminUpdatedFeeHandler(feedId, feeHandler);
    } 

    /**
     * @notice Admin function to switch off the oracle contract
     */
    function turnOff() external onlyOwner {
        switchedOn = false;

        emit UpshotOracleV2OracleAdminSwitchedOff();
    }

    /**
     * @notice Admin function to switch on the oracle contract
     */
    function turnOn() external onlyOwner {
        switchedOn = true;

        emit UpshotOracleV2OracleAdminSwitchedOn();
    }

    /**
     * @notice Admin function to update the total fee to be paid per piece of data
     * 
     * @param feedId The feedId to update the total fee for
     * @param totalFee The total fee to be paid per piece of data
     */
    function updateTotalFee(uint256 feedId, uint128 totalFee) external onlyOwner {
        if (0 < totalFee && totalFee < 1_000) {
            revert UpshotOracleV2InvalidTotalFee();
        }
        feed[feedId].totalFee = totalFee;

        emit UpshotOracleV2OracleAdminUpdatedFeePerDataVerification(totalFee);
    }
}
