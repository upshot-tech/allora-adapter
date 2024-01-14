// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;


import { IAggregator } from './interface/IAggregator.sol';
import { IFeeHandler } from './interface/IFeeHandler.sol';
import { UpshotAdapterNumericData, NumericData, IUpshotAdapter, Topic, TopicView, TopicValue } from './interface/IUpshotAdapter.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EIP712 } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import { EnumerableSet } from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

struct UpshotAdapterConstructorArgs {
    address admin;
    address protocolFeeReceiver;
}

contract UpshotAdapter is IUpshotAdapter, Ownable2Step, EIP712 {

    /// @dev The data for each topic. Call getTopic function for access to structured data
    mapping(uint256 topicId => Topic) internal topic;

    /// @dev The value for each topic
    mapping(uint256 topicId => mapping(bytes extraData => TopicValue)) public topicValue;

    /// @dev The next topicId to use
    uint256 public nextTopicId = 1;

    /// @dev Whether the UpshotAdapter contract is switched on and usable
    bool public switchedOn = true;

    /// @dev The fee collected by the protocol per verification
    uint256 public protocolFee = 0;

    /// @dev the address that receives the protocol fee
    address public protocolFeeReceiver;

    bytes32 public constant NUMERIC_DATA_TYPEHASH = keccak256(
        "NumericData(uint256 topicId,uint256 timestamp,uint256 numericValue,bytes extraData)"
    );

    constructor(UpshotAdapterConstructorArgs memory args) 
        EIP712("UpshotAdapter", "1") 
    {
        _transferOwnership(args.admin);

        _setProtocolFeeReceiver(args.protocolFeeReceiver);
    }

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    // main interface events
    event UpshotAdapterV2AdapterVerifiedData(uint256 topicId, uint256 numericData, address[] dataProviders);
    
    // topic owner update events
    event UpshotAdapterV2TopicAdded(TopicView topicView);
    event UpshotAdapterV2AdapterTopicOwnerUpdatedDataProviderQuorum(uint256 topicId, uint48 dataProviderQuorum);
    event UpshotAdapterV2AdapterTopicOwnerUpdatedDataValiditySeconds(uint256 topicId, uint48 dataValiditySeconds);
    event UpshotAdapterV2AdapterTopicOwnerAddedDataProvider(uint256 topicId, address dataProvider);
    event UpshotAdapterV2AdapterTopicOwnerRemovedDataProvider(address dataProvider);
    event UpshotAdapterV2AdapterTopicOwnerUpdatedAggregator(uint256 topicId, IAggregator aggregator);
    event UpshotAdapterV2AdapterTopicOwnerUpdatedFeeHandler(uint256 topicId, IFeeHandler feeHandler);
    event UpshotAdapterV2AdapterTopicOwnerUpdatedFee(uint128 totalFee);
    event UpshotAdapterV2AdapterTopicOwnerUpdatedOwner(uint256 topicId, address newOwner);
    event UpshotAdapterV2AdapterTopicOwnerTopicTurnedOff(uint256 topicId);
    event UpshotAdapterV2AdapterTopicOwnerTopicTurnedOn(uint256 topicId);

    // adapter admin updates
    event UpshotAdapterV2AdapterAdminUpdatedProtocolFee(uint256 newProtocolFee);
    event UpshotAdapterV2AdapterAdminUpdatedProtocolFeeReceiver(address protocolFeeReceiver);
    event UpshotAdapterV2AdapterAdminTopicTurnedOff(uint256 topicId);
    event UpshotAdapterV2AdapterAdminTopicTurnedOn(uint256 topicId);
    event UpshotAdapterV2AdapterAdminTurnedOff();
    event UpshotAdapterV2AdapterAdminTurnedOn();

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    // verification errors
    error UpshotAdapterV2NotSwitchedOn();
    error UpshotAdapterV2NoDataProvided();
    error UpshotAdapterV2OwnerTurnedTopicOff();
    error UpshotAdapterV2AdminTurnedTopicOff();
    error UpshotAdapterV2InsufficientPayment();
    error UpshotAdapterV2NotEnoughData();
    error UpshotAdapterV2TopicMismatch();
    error UpshotAdapterV2ExtraDataMismatch();
    error UpshotAdapterV2InvalidDataTime();
    error UpshotAdapterV2InvalidDataProvider();
    error UpshotAdapterV2DuplicateDataProvider();
    error UpshotAdapterV2EthTransferFailed();

    // parameter update errors
    error UpshotAdapterV2InvalidTopicTitle();
    error UpshotAdapterV2OnlyTopicOwner();
    error UpshotAdapterV2InvalidTotalFee();
    error UpshotAdapterV2InvalidFeeHandler();
    error UpshotAdapterV2InvalidAggregator();
    error UpshotAdapterV2InvalidDataProviderQuorum();
    error UpshotAdapterV2InvalidDataValiditySeconds();
    error UpshotAdapterV2InvalidProtocolFeeReceiver();
    error UpshotAdapterV2ProtocolFeeTooHigh();

    // casting errors
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************
    ///@inheritdoc IUpshotAdapter
    function verifyData(
        UpshotAdapterNumericData calldata nd
    ) external payable override returns (uint256 numericValue) {
        if (!switchedOn) {
            revert UpshotAdapterV2NotSwitchedOn();
        }

        uint256 dataCount = nd.signedNumericData.length;

        if (dataCount == 0) {
            revert UpshotAdapterV2NoDataProvided();
        }

        uint256 topicId = nd.signedNumericData[0].numericData.topicId;
        bytes calldata extraData = nd.signedNumericData[0].numericData.extraData;

        if (!topic[topicId].config.ownerSwitchedOn) {
            revert UpshotAdapterV2OwnerTurnedTopicOff();
        }

        if (!topic[topicId].config.adminSwitchedOn) {
            revert UpshotAdapterV2AdminTurnedTopicOff();
        }

        // load once to save gas
        uint256 _protocolFee = protocolFee;

        if (msg.value < topic[topicId].config.totalFee + _protocolFee) {
            revert UpshotAdapterV2InsufficientPayment();
        }

        if (dataCount < topic[topicId].config.dataProviderQuorum) {
            revert UpshotAdapterV2NotEnoughData();
        }

        uint256[] memory dataList = new uint256[](dataCount);
        address[] memory dataProviders = new address[](dataCount);
        NumericData calldata numericData;

        for(uint256 i = 0; i < dataCount;) {
            numericData = nd.signedNumericData[i].numericData;

            if (numericData.topicId != topicId) {
                revert UpshotAdapterV2TopicMismatch();
            }

            if (!_equalBytes(numericData.extraData, extraData)) {
                revert UpshotAdapterV2ExtraDataMismatch();
            }

            if (
                block.timestamp < numericData.timestamp ||
                numericData.timestamp + topic[topicId].config.dataValiditySeconds < block.timestamp
            ) {
                revert UpshotAdapterV2InvalidDataTime();
            }

            address dataProvider = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(getMessage(numericData)), 
                nd.signedNumericData[i].signature
            );

            if (!EnumerableSet.contains(topic[topicId].validDataProviders, dataProvider)) {
                revert UpshotAdapterV2InvalidDataProvider();
            }

            for (uint256 j = 0; j < i;) {
                if (dataProvider == dataProviders[j]) {
                    revert UpshotAdapterV2DuplicateDataProvider();
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

        topicValue[topicId][extraData] = TopicValue({
            recentValue: _toUint192(numericValue),
            recentValueTime: _toUint64(block.timestamp)
        });
        
        if (_protocolFee != 0) {
            _safeTransferETH(protocolFeeReceiver, _protocolFee);
        }

        topic[topicId].config.feeHandler.handleFees{value: msg.value - _protocolFee}(
            topic[topicId].config.owner,
            dataProviders, 
            nd.extraData
        );

        emit UpshotAdapterV2AdapterVerifiedData(topicId, numericValue, dataProviders);
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
        NumericData calldata numericData
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
            revert UpshotAdapterV2OnlyTopicOwner();
        }
        _;
    }

    /**
     * @notice Safely transfer ETH to an address
     * 
     * @param to The address to send ETH to
     * @param value The amount of ETH to send
     */
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) {
            revert UpshotAdapterV2EthTransferFailed();
        }
    }

    /**
     * @dev Update the protocol fee receiver. Pulled out into a helper function because 
     *   this is called in the constructor and in the admin function
     * 
     * @param protocolFeeReceiver_ The new protocol fee receiver
     */
    function _setProtocolFeeReceiver(address protocolFeeReceiver_) internal {
        if (protocolFeeReceiver_ == address(0)) {
            revert UpshotAdapterV2InvalidProtocolFeeReceiver();
        }

        protocolFeeReceiver = protocolFeeReceiver_;

        emit UpshotAdapterV2AdapterAdminUpdatedProtocolFeeReceiver(protocolFeeReceiver_);
    }

    /**
     * @notice Check if two bytes calldata are equal
     * 
     * @param a The first bytes calldata
     * @param b The second bytes calldata
     * @return Whether the bytes calldata are equal
     */
    function _equalBytes(bytes calldata a, bytes calldata b) internal pure returns (bool) {
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
            revert UpshotAdapterV2InvalidTopicTitle();
        }
        newTopicId = nextTopicId++;
        topic[newTopicId].config = topicView.config;

        for (uint256 i = 0; i < topicView.validDataProviders.length;) {
            EnumerableSet.add(topic[newTopicId].validDataProviders, topicView.validDataProviders[i]);
            unchecked { ++i; }
        }

        emit UpshotAdapterV2TopicAdded(topicView);
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
            revert UpshotAdapterV2InvalidDataProviderQuorum();
        }

        topic[topicId].config.dataProviderQuorum = dataProviderQuorum;

        emit UpshotAdapterV2AdapterTopicOwnerUpdatedDataProviderQuorum(topicId, dataProviderQuorum);
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
            revert UpshotAdapterV2InvalidDataValiditySeconds();
        }

        topic[topicId].config.dataValiditySeconds = dataValiditySeconds;

        emit UpshotAdapterV2AdapterTopicOwnerUpdatedDataValiditySeconds(topicId, dataValiditySeconds);
    }

    /**
     * @notice Topic owner function to update the total fee
     * 
     * @param topicId The topicId to update the total fee for
     * @param totalFee The total fee to be paid per piece of data
     */
    function updateTotalFee(uint256 topicId, uint96 totalFee) external onlyTopicOwner(topicId) {
        if (0 < totalFee && totalFee < 1_000) {
            revert UpshotAdapterV2InvalidTotalFee();
        }
        topic[topicId].config.totalFee = totalFee;

        emit UpshotAdapterV2AdapterTopicOwnerUpdatedFee(totalFee);
    }

  /**
     * @notice Topic owner function to add a data provider
     * 
     * @param topicId The topicId to add the data provider to
     * @param dataProvider The data provider to add
     */
    function addDataProvider(uint256 topicId, address dataProvider) external onlyTopicOwner(topicId) {
        EnumerableSet.add(topic[topicId].validDataProviders, dataProvider);

        emit UpshotAdapterV2AdapterTopicOwnerAddedDataProvider(topicId, dataProvider);
    }

    /**
     * @notice Topic owner function to remove a data provider
     * 
     * @param topicId The topicId to remove the data provider from
     * @param dataProvider the data provider to remove
     */
    function removeDataProvider(uint256 topicId, address dataProvider) external onlyTopicOwner(topicId) {
        EnumerableSet.remove(topic[topicId].validDataProviders, dataProvider);

        emit UpshotAdapterV2AdapterTopicOwnerRemovedDataProvider(dataProvider);
    }

    /**
     * @notice Topic owner function to turn off a topic
     * 
     * @param topicId The topicId of the topic to turn off
     */
    function turnOffTopic(uint256 topicId) external onlyTopicOwner(topicId) {
        topic[topicId].config.ownerSwitchedOn = false;
        
        emit UpshotAdapterV2AdapterTopicOwnerTopicTurnedOff(topicId);
    }

    /**
     * @notice Topic owner function to turn on a topic
     * 
     * @param topicId The topicId of the topic to turn on
     */
    function turnOnTopic(uint256 topicId) external onlyTopicOwner(topicId) {
        topic[topicId].config.ownerSwitchedOn = true;
        
        emit UpshotAdapterV2AdapterTopicOwnerTopicTurnedOn(topicId);
    }

    /**
     * @notice Topic owner function to update the aggregator to use for aggregating numeric data
     * 
     * @param topicId The topicId to update the aggregator for
     * @param aggregator The aggregator to use for aggregating numeric data
     */
    function updateAggregator(uint256 topicId, IAggregator aggregator) external onlyTopicOwner(topicId) {
        if (address(aggregator) == address(0)) {
            revert UpshotAdapterV2InvalidAggregator();
        }

        topic[topicId].config.aggregator = aggregator;

        emit UpshotAdapterV2AdapterTopicOwnerUpdatedAggregator(topicId, aggregator);
    }

    /**
     * @notice Topic owner function to update the fee handler to use for handling fees
     * 
     * @param topicId The topicId to update the fee handler for
     * @param feeHandler The fee handler to use for handling fees
     */
    function updateFeeHandler(uint256 topicId, IFeeHandler feeHandler) external onlyTopicOwner(topicId) {
        if (address(feeHandler) == address(0)) {
            revert UpshotAdapterV2InvalidFeeHandler();
        }

        topic[topicId].config.feeHandler = feeHandler;

        emit UpshotAdapterV2AdapterTopicOwnerUpdatedFeeHandler(topicId, feeHandler);
    } 

    /**
     * @notice Topic owner function to update the owner of the topic 
     * 
     * @param topicId The topicId to update the fee handler for
     * @param owner_ The new owner of the topic
     */
    function updateTopicOwner(uint256 topicId, address owner_) external onlyTopicOwner(topicId) {
        topic[topicId].config.owner = owner_;

        emit UpshotAdapterV2AdapterTopicOwnerUpdatedOwner(topicId, owner_);
    } 

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************
    /**
     * @notice Admin function to switch off the adapter contract
     */
    function adminTurnOffAdapter() external onlyOwner {
        switchedOn = false;

        emit UpshotAdapterV2AdapterAdminTurnedOff();
    }

    /**
     * @notice Admin function to switch on the adapter contract
     */
    function adminTurnOnAdapter() external onlyOwner {
        switchedOn = true;

        emit UpshotAdapterV2AdapterAdminTurnedOn();
    }
    
    /**
     * @notice Admin function to turn off a topic
     * 
     * @param topicId The topicId of the topic to turn off
     */
    function adminTurnOffTopic(uint256 topicId) external onlyOwner {
        topic[topicId].config.adminSwitchedOn = false;
        
        emit UpshotAdapterV2AdapterAdminTopicTurnedOff(topicId);
    }

    /**
     * @notice Admin function to turn on a topic
     * 
     * @param topicId The topicId of the topic to turn on
     */
    function adminTurnOnTopic(uint256 topicId) external onlyOwner {
        topic[topicId].config.adminSwitchedOn = true;
        
        emit UpshotAdapterV2AdapterAdminTopicTurnedOn(topicId);
    }

    /**
     * @notice Admin function to update the portion of the total fee that goes to the protocol
     * 
     * @param protocolFee_ The new protocol fee
     */
    function adminSetProtocolFee(uint256 protocolFee_) external onlyOwner {
        if (protocolFee_ > 0.5 ether) {
            revert UpshotAdapterV2ProtocolFeeTooHigh();
        }

        protocolFee = protocolFee_;

        emit UpshotAdapterV2AdapterAdminUpdatedProtocolFee(protocolFee_);
    }

    /**
     * @notice Admin function to update the protocol fee receiver
     * 
     * @param protocolFeeReceiver_ The new protocol fee receiver
     */
    function adminSetProtocolFeeReceiver(address protocolFeeReceiver_) external onlyOwner {
        _setProtocolFeeReceiver(protocolFeeReceiver_);
    }
}
