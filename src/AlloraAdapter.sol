// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;


import { IAggregator } from './interface/IAggregator.sol';
import { IFeeHandler } from './interface/IFeeHandler.sol';
import { AlloraAdapterNumericData, NumericData, IAlloraAdapter, Topic, TopicView, TopicValue } from './interface/IAlloraAdapter.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EIP712 } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { EnumerableSet } from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

struct AlloraAdapterConstructorArgs {
    address admin;
}

contract AlloraAdapter is IAlloraAdapter, Ownable2Step, EIP712 {

    /// @dev The data for each topic. Call getTopic function for access to structured data
    mapping(uint256 topicId => Topic) internal topic;

    /// @dev The value for each topic
    mapping(uint256 topicId => mapping(bytes extraData => TopicValue)) public topicValue;

    /// @dev The next topicId to use
    uint256 public nextTopicId = 1;

    /// @dev Whether the AlloraAdapter contract is switched on and usable
    bool public switchedOn = true;

    bytes32 public constant NUMERIC_DATA_TYPEHASH = keccak256(
        "NumericData(uint256 topicId,uint256 timestamp,uint256 numericValue,bytes extraData)"
    );

    constructor(AlloraAdapterConstructorArgs memory args) 
        EIP712("AlloraAdapter", "1") 
    {
        _transferOwnership(args.admin);
    }

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    // main interface events
    event AlloraAdapterV2AdapterVerifiedData(uint256 topicId, uint256 numericData, address[] dataProviders, bytes extraData);
    
    // topic owner update events
    event AlloraAdapterV2TopicAdded(TopicView topicView);
    event AlloraAdapterV2AdapterTopicOwnerUpdatedDataProviderQuorum(uint256 topicId, uint48 dataProviderQuorum);
    event AlloraAdapterV2AdapterTopicOwnerUpdatedDataValiditySeconds(uint256 topicId, uint48 dataValiditySeconds);
    event AlloraAdapterV2AdapterTopicOwnerAddedDataProvider(uint256 topicId, address dataProvider);
    event AlloraAdapterV2AdapterTopicOwnerRemovedDataProvider(address dataProvider);
    event AlloraAdapterV2AdapterTopicOwnerUpdatedAggregator(uint256 topicId, IAggregator aggregator);
    event AlloraAdapterV2AdapterTopicOwnerUpdatedOwner(uint256 topicId, address newOwner);
    event AlloraAdapterV2AdapterTopicOwnerTopicTurnedOff(uint256 topicId);
    event AlloraAdapterV2AdapterTopicOwnerTopicTurnedOn(uint256 topicId);

    // adapter admin updates
    event AlloraAdapterV2AdapterAdminTopicTurnedOff(uint256 topicId);
    event AlloraAdapterV2AdapterAdminTopicTurnedOn(uint256 topicId);
    event AlloraAdapterV2AdapterAdminTurnedOff();
    event AlloraAdapterV2AdapterAdminTurnedOn();

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    // verification errors
    error AlloraAdapterV2NotSwitchedOn();
    error AlloraAdapterV2NoDataProvided();
    error AlloraAdapterV2OwnerTurnedTopicOff();
    error AlloraAdapterV2AdminTurnedTopicOff();
    error AlloraAdapterV2NotEnoughData();
    error AlloraAdapterV2TopicMismatch();
    error AlloraAdapterV2ExtraDataMismatch();
    error AlloraAdapterV2InvalidDataTime();
    error AlloraAdapterV2InvalidDataProvider();
    error AlloraAdapterV2DuplicateDataProvider();

    // parameter update errors
    error AlloraAdapterV2InvalidTopicTitle();
    error AlloraAdapterV2OnlyTopicOwner();
    error AlloraAdapterV2InvalidAggregator();
    error AlloraAdapterV2InvalidDataProviderQuorum();
    error AlloraAdapterV2InvalidDataValiditySeconds();

    // casting errors
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************
    ///@inheritdoc IAlloraAdapter
    function verifyData(
        AlloraAdapterNumericData memory nd
    ) external override returns (
        uint256 numericValue, 
        uint256 topicId, 
        address[] memory dataProviders, 
        bytes memory extraData
    ) {
        (numericValue, topicId, dataProviders, extraData) = _verifyData(nd);

        topicValue[topicId][extraData] = TopicValue({
            recentValue: _toUint192(numericValue),
            recentValueTime: _toUint64(block.timestamp)
        });

        emit AlloraAdapterV2AdapterVerifiedData(topicId, numericValue, dataProviders, extraData);
    }

    ///@inheritdoc IAlloraAdapter
    function verifyDataViewOnly(
        AlloraAdapterNumericData memory nd
    ) external view override returns (
        uint256 numericValue, 
        uint256 topicId, 
        address[] memory dataProviders, 
        bytes memory extraData
    ) {
        (numericValue, topicId, dataProviders, extraData) = _verifyData(nd);
    }

    /**
     * @notice Verify the data provided by the data providers
     * 
     * @param nd The data to verify
     */
    function _verifyData(
        AlloraAdapterNumericData memory nd
    ) internal view returns (
        uint256 numericValue, 
        uint256 topicId, 
        address[] memory dataProviders, 
        bytes memory extraData
    ) {
        if (!switchedOn) {
            revert AlloraAdapterV2NotSwitchedOn();
        }

        uint256 dataCount = nd.signedNumericData.length;

        if (dataCount == 0) {
            revert AlloraAdapterV2NoDataProvided();
        }

        topicId = nd.signedNumericData[0].numericData.topicId;
        extraData = nd.signedNumericData[0].numericData.extraData;

        if (!topic[topicId].config.ownerSwitchedOn) {
            revert AlloraAdapterV2OwnerTurnedTopicOff();
        }

        if (!topic[topicId].config.adminSwitchedOn) {
            revert AlloraAdapterV2AdminTurnedTopicOff();
        }

        if (dataCount < topic[topicId].config.dataProviderQuorum) {
            revert AlloraAdapterV2NotEnoughData();
        }

        uint256[] memory dataList = new uint256[](dataCount);
        dataProviders = new address[](dataCount);
        NumericData memory numericData;

        for(uint256 i = 0; i < dataCount;) {
            numericData = nd.signedNumericData[i].numericData;

            if (numericData.topicId != topicId) {
                revert AlloraAdapterV2TopicMismatch();
            }

            if (!_equalBytes(numericData.extraData, extraData)) {
                revert AlloraAdapterV2ExtraDataMismatch();
            }

            if (
                block.timestamp < numericData.timestamp ||
                numericData.timestamp + topic[topicId].config.dataValiditySeconds < block.timestamp
            ) {
                revert AlloraAdapterV2InvalidDataTime();
            }

            address dataProvider = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(getMessage(numericData)), 
                nd.signedNumericData[i].signature
            );

            if (!EnumerableSet.contains(topic[topicId].validDataProviders, dataProvider)) {
                revert AlloraAdapterV2InvalidDataProvider();
            }

            for (uint256 j = 0; j < i;) {
                if (dataProvider == dataProviders[j]) {
                    revert AlloraAdapterV2DuplicateDataProvider();
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

        numericValue = topic[topicId].config.aggregator.aggregate(dataList, nd.extraData);
    }

    // ***************************************************************
    // * ===================== VIEW FUNCTIONS ====================== *
    // ***************************************************************
    /**
     * @notice The message that must be signed by the provider to provide valid data
     *   recognized by verifyData
     * 
     * @param numericData The numerical data to verify
     */
    function getMessage(
        NumericData memory numericData
    ) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            NUMERIC_DATA_TYPEHASH,
            numericData.topicId,
            numericData.timestamp,
            numericData.numericValue,
            numericData.extraData
        )));
    }

    /**
     * @notice Get the topic data for a given topicId
     * 
     * @param topicId The topicId to get the topic data for
     * @return topicView The topic data
     */
    function getTopic(uint256 topicId) external view override returns (TopicView memory topicView) {
        topicView = TopicView({
            config: topic[topicId].config,
            validDataProviders: EnumerableSet.values(topic[topicId].validDataProviders)
        });
    }

    /**
     * @notice Get the topic data for a given topicId
     * 
     * @param topicId The topicId to get the topic data for
     * @param extraData The extraData to get the topic data for
     * @return topicValue The topic data
     */
    function getTopicValue(
        uint256 topicId, 
        bytes calldata extraData
    ) external view override returns (TopicValue memory) {
        return topicValue[topicId][extraData];
    }

    // ***************************************************************
    // * ==================== INTERNAL HELPERS ===================== *
    // ***************************************************************
    /**
     * @dev Modifier to check that the caller is the owner of the topic
     * 
     * @param topicId The topicId to validate the owner for
     */
    modifier onlyTopicOwner(uint256 topicId) {
        if (msg.sender != topic[topicId].config.owner) {
            revert AlloraAdapterV2OnlyTopicOwner();
        }
        _;
    }

    /**
     * @notice Check if two bytes calldata are equal
     * 
     * @param a The first bytes calldata
     * @param b The second bytes calldata
     * @return Whether the bytes calldata are equal
     */
    function _equalBytes(bytes memory a, bytes memory b) internal pure returns (bool) {
        uint256 aLength = a.length;
        // Check if their lengths are equal
        if (aLength != b.length) {
            return false;
        }

        // Compare byte-by-byte
        for (uint i = 0; i < aLength; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }

        // Return true if all bytes are equal
        return true;
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function _toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function _toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @notice Internal helper to add a new topic
     * 
     * @param topicView The topic data to add 
     */
    function _addTopic(
        TopicView calldata topicView
    ) internal returns (uint256 newTopicId) {
        if (bytes(topicView.config.title).length == 0) {
            revert AlloraAdapterV2InvalidTopicTitle();
        }
        newTopicId = nextTopicId++;
        topic[newTopicId].config = topicView.config;

        for (uint256 i = 0; i < topicView.validDataProviders.length;) {
            EnumerableSet.add(topic[newTopicId].validDataProviders, topicView.validDataProviders[i]);
            unchecked { ++i; }
        }

        emit AlloraAdapterV2TopicAdded(topicView);
    }

    // ***************************************************************
    // * ==================== TOPIC MANAGEMENT ===================== *
    // ***************************************************************

    /**
     * @notice Function to add a new topic, can be called by anyone
     * 
     * @param topicView The topic data to add
     */
    function addTopic(
        TopicView calldata topicView
    ) external returns (uint256 newTopicId) {
        return _addTopic(topicView);
    }

    /**
     * @notice Function to add multiple new topics in order, can be called by anyone
     * 
     * @param topicViews The data for the topics to add
     */
    function addTopics(
        TopicView[] calldata topicViews
    ) external returns (uint256[] memory newTopicIds) {
        newTopicIds = new uint256[](topicViews.length);

        for (uint256 i = 0; i < topicViews.length;) {
            newTopicIds[i] = _addTopic(topicViews[i]);
            unchecked { ++i; }
        }
    }

    /**
     * @notice Topic owner function to update the minimum number of data providers needed to verify data
     * 
     * @param topicId The topicId to update the minimum number of data providers required
     * @param dataProviderQuorum The minimum number of data providers required
     */
    function updateDataProviderQuorum(
        uint256 topicId, 
        uint48 dataProviderQuorum
    ) external onlyTopicOwner(topicId) {
        if (dataProviderQuorum == 0) {
            revert AlloraAdapterV2InvalidDataProviderQuorum();
        }

        topic[topicId].config.dataProviderQuorum = dataProviderQuorum;

        emit AlloraAdapterV2AdapterTopicOwnerUpdatedDataProviderQuorum(topicId, dataProviderQuorum);
    }

    /**
     * @notice Topic owner function to update the number of seconds data is valid for
     * 
     * @param topicId The topicId to update the number of seconds data is valid for
     * @param dataValiditySeconds The number of seconds data is valid for
     */
    function updateDataValiditySeconds(
        uint256 topicId, 
        uint48 dataValiditySeconds
    ) external onlyTopicOwner(topicId) {
        if (dataValiditySeconds == 0) { 
            revert AlloraAdapterV2InvalidDataValiditySeconds();
        }

        topic[topicId].config.dataValiditySeconds = dataValiditySeconds;

        emit AlloraAdapterV2AdapterTopicOwnerUpdatedDataValiditySeconds(topicId, dataValiditySeconds);
    }

  /**
     * @notice Topic owner function to add a data provider
     * 
     * @param topicId The topicId to add the data provider to
     * @param dataProvider The data provider to add
     */
    function addDataProvider(uint256 topicId, address dataProvider) external onlyTopicOwner(topicId) {
        EnumerableSet.add(topic[topicId].validDataProviders, dataProvider);

        emit AlloraAdapterV2AdapterTopicOwnerAddedDataProvider(topicId, dataProvider);
    }

    /**
     * @notice Topic owner function to remove a data provider
     * 
     * @param topicId The topicId to remove the data provider from
     * @param dataProvider the data provider to remove
     */
    function removeDataProvider(uint256 topicId, address dataProvider) external onlyTopicOwner(topicId) {
        EnumerableSet.remove(topic[topicId].validDataProviders, dataProvider);

        emit AlloraAdapterV2AdapterTopicOwnerRemovedDataProvider(dataProvider);
    }

    /**
     * @notice Topic owner function to turn off a topic
     * 
     * @param topicId The topicId of the topic to turn off
     */
    function turnOffTopic(uint256 topicId) external onlyTopicOwner(topicId) {
        topic[topicId].config.ownerSwitchedOn = false;
        
        emit AlloraAdapterV2AdapterTopicOwnerTopicTurnedOff(topicId);
    }

    /**
     * @notice Topic owner function to turn on a topic
     * 
     * @param topicId The topicId of the topic to turn on
     */
    function turnOnTopic(uint256 topicId) external onlyTopicOwner(topicId) {
        topic[topicId].config.ownerSwitchedOn = true;
        
        emit AlloraAdapterV2AdapterTopicOwnerTopicTurnedOn(topicId);
    }

    /**
     * @notice Topic owner function to update the aggregator to use for aggregating numeric data
     * 
     * @param topicId The topicId to update the aggregator for
     * @param aggregator The aggregator to use for aggregating numeric data
     */
    function updateAggregator(uint256 topicId, IAggregator aggregator) external onlyTopicOwner(topicId) {
        if (address(aggregator) == address(0)) {
            revert AlloraAdapterV2InvalidAggregator();
        }

        topic[topicId].config.aggregator = aggregator;

        emit AlloraAdapterV2AdapterTopicOwnerUpdatedAggregator(topicId, aggregator);
    }

    /**
     * @notice Topic owner function to update the owner of the topic 
     * 
     * @param topicId The topicId to update the fee handler for
     * @param owner_ The new owner of the topic
     */
    function updateTopicOwner(uint256 topicId, address owner_) external onlyTopicOwner(topicId) {
        topic[topicId].config.owner = owner_;

        emit AlloraAdapterV2AdapterTopicOwnerUpdatedOwner(topicId, owner_);
    } 

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************
    /**
     * @notice Admin function to switch off the adapter contract
     */
    function adminTurnOffAdapter() external onlyOwner {
        switchedOn = false;

        emit AlloraAdapterV2AdapterAdminTurnedOff();
    }

    /**
     * @notice Admin function to switch on the adapter contract
     */
    function adminTurnOnAdapter() external onlyOwner {
        switchedOn = true;

        emit AlloraAdapterV2AdapterAdminTurnedOn();
    }
    
    /**
     * @notice Admin function to turn off a topic
     * 
     * @param topicId The topicId of the topic to turn off
     */
    function adminTurnOffTopic(uint256 topicId) external onlyOwner {
        topic[topicId].config.adminSwitchedOn = false;
        
        emit AlloraAdapterV2AdapterAdminTopicTurnedOff(topicId);
    }

    /**
     * @notice Admin function to turn on a topic
     * 
     * @param topicId The topicId of the topic to turn on
     */
    function adminTurnOnTopic(uint256 topicId) external onlyOwner {
        topic[topicId].config.adminSwitchedOn = true;
        
        emit AlloraAdapterV2AdapterAdminTopicTurnedOn(topicId);
    }
}
