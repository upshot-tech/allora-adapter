// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;


import { IAggregator } from './interface/IAggregator.sol';
import { IFeeHandler } from './interface/IFeeHandler.sol';
import { UpshotOracleNumericData, NumericData, IOracle, Topic, TopicView } from './interface/IOracle.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

struct OracleConstructorArgs {
    address admin;
    address protocolFeeReceiver;
}

contract Oracle is IOracle, Ownable2Step {

    /// @dev The data for each topic. Call getTopic function for access to structured data
    mapping(uint256 topicId => Topic) internal topic;

    /// @dev The next topicId to use
    uint256 public nextTopicId = 1;

    /// @dev Whether the oracle contract is switched on and usable
    bool public switchedOn = true;

    /// @dev The fee collected by the protocol per verification
    uint256 public protocolFee = 0;

    /// @dev the address that receives the protocol fee
    address public protocolFeeReceiver;

    constructor(
        OracleConstructorArgs memory args
    ) {
        _transferOwnership(args.admin);

        _setProtocolFeeReceiver(args.protocolFeeReceiver);
    }

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    // main interface events
    event UpshotOracleV2OracleVerifiedData(uint256 topicId, uint256 numericData, address[] dataProviders);
    
    // topic owner update events
    event UpshotOracleV2TopicAdded(TopicView topicView);
    event UpshotOracleV2OracleTopicOwnerUpdatedDataProviderQuorum(uint256 topicId, uint48 dataProviderQuorum);
    event UpshotOracleV2OracleTopicOwnerUpdatedDataValiditySeconds(uint256 topicId, uint48 dataValiditySeconds);
    event UpshotOracleV2OracleTopicOwnerAddedDataProvider(uint256 topicId, address dataProvider);
    event UpshotOracleV2OracleTopicOwnerRemovedDataProvider(address dataProvider);
    event UpshotOracleV2OracleTopicOwnerUpdatedAggregator(uint256 topicId, IAggregator aggregator);
    event UpshotOracleV2OracleTopicOwnerUpdatedFeeHandler(uint256 topicId, IFeeHandler feeHandler);
    event UpshotOracleV2OracleTopicOwnerUpdatedFee(uint128 totalFee);
    event UpshotOracleV2OracleTopicOwnerUpdatedOwner(uint256 topicId, address newOwner);
    event UpshotOracleV2OracleTopicOwnerTopicTurnedOff(uint256 topicId);
    event UpshotOracleV2OracleTopicOwnerTopicTurnedOn(uint256 topicId);

    // oracle admin updates
    event UpshotOracleV2OracleAdminUpdatedProtocolFee(uint256 newProtocolFee);
    event UpshotOracleV2OracleAdminUpdatedProtocolFeeReceiver(address protocolFeeReceiver);
    event UpshotOracleV2OracleAdminTopicTurnedOff(uint256 topicId);
    event UpshotOracleV2OracleAdminTopicTurnedOn(uint256 topicId);
    event UpshotOracleV2OracleAdminOracleTurnedOff();
    event UpshotOracleV2OracleAdminOracleTurnedOn();

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    // verification errors
    error UpshotOracleV2NotSwitchedOn();
    error UpshotOracleV2NoDataProvided();
    error UpshotOracleV2OwnerTurnedTopicOff();
    error UpshotOracleV2AdminTurnedTopicOff();
    error UpshotOracleV2InsufficientPayment();
    error UpshotOracleV2NotEnoughData();
    error UpshotOracleV2TopicMismatch();
    error UpshotOracleV2InvalidDataTime();
    error UpshotOracleV2InvalidDataProvider();
    error UpshotOracleV2DuplicateDataProvider();
    error UpshotOracleV2EthTransferFailed();

    // parameter update errors
    error UpshotOracleV2InvalidTopicTitle();
    error UpshotOracleV2OnlyTopicOwner();
    error UpshotOracleV2InvalidTotalFee();
    error UpshotOracleV2InvalidFeeHandler();
    error UpshotOracleV2InvalidAggregator();
    error UpshotOracleV2InvalidDataProviderQuorum();
    error UpshotOracleV2InvalidDataValiditySeconds();
    error UpshotOracleV2InvalidProtocolFeeReceiver();
    error UpshotOracleV2ProtocolFeeTooHigh();

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

        uint256 topicId = nd.signedNumericData[0].numericData.topicId;

        if (!topic[topicId].config.ownerSwitchedOn) {
            revert UpshotOracleV2OwnerTurnedTopicOff();
        }

        if (!topic[topicId].config.adminSwitchedOn) {
            revert UpshotOracleV2AdminTurnedTopicOff();
        }

        // load once to save gas
        uint256 _protocolFee = protocolFee;

        if (msg.value < topic[topicId].config.totalFee + _protocolFee) {
            revert UpshotOracleV2InsufficientPayment();
        }

        if (dataCount < topic[topicId].config.dataProviderQuorum) {
            revert UpshotOracleV2NotEnoughData();
        }

        uint256[] memory dataList = new uint256[](dataCount);
        address[] memory dataProviders = new address[](dataCount);
        NumericData calldata numericData;

        for(uint256 i = 0; i < dataCount;) {
            numericData = nd.signedNumericData[i].numericData;

            if (numericData.topicId != topicId) {
                revert UpshotOracleV2TopicMismatch();
            }

            if (
                block.timestamp < numericData.timestamp ||
                numericData.timestamp + topic[topicId].config.dataValiditySeconds < block.timestamp
            ) {
                revert UpshotOracleV2InvalidDataTime();
            }

            address dataProvider =
                ECDSA.recover(
                    ECDSA.toEthSignedMessageHash(getMessage(numericData)),
                    nd.signedNumericData[i].signature
                );

            if (!EnumerableSet.contains(topic[topicId].validDataProviders, dataProvider)) {
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

        numericValue = topic[topicId].config.aggregator.aggregate(dataList, nd.extraData);

        topic[topicId].config.recentValue = numericValue;
        topic[topicId].config.recentValueTime = uint48(block.timestamp);

        if (_protocolFee != 0) {
            _safeTransferETH(protocolFeeReceiver, _protocolFee);
        }

        topic[topicId].config.feeHandler.handleFees{value: msg.value - _protocolFee}(
            topic[topicId].config.owner,
            dataProviders, 
            nd.extraData
        );

        emit UpshotOracleV2OracleVerifiedData(topicId, numericValue, dataProviders);
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
        return keccak256(abi.encodePacked(
            block.chainid, 
            numericData.topicId,
            numericData.timestamp,
            numericData.numericValue, 
            numericData.extraData
        ));
    }

    /**
     * @notice Get the topic data for a given topicId
     * 
     * @param topicId The topicId to get the topic data for
     * @return topicView The topic data
     */
    function getTopic(uint256 topicId) external view returns (TopicView memory topicView) {
        topicView = TopicView({
            config: topic[topicId].config,
            validDataProviders: EnumerableSet.values(topic[topicId].validDataProviders)
        });
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
            revert UpshotOracleV2OnlyTopicOwner();
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
            revert UpshotOracleV2EthTransferFailed();
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
            revert UpshotOracleV2InvalidProtocolFeeReceiver();
        }

        protocolFeeReceiver = protocolFeeReceiver_;

        emit UpshotOracleV2OracleAdminUpdatedProtocolFeeReceiver(protocolFeeReceiver_);
    }

    // ***************************************************************
    // * ====================== FEED UPDATES ======================= *
    // ***************************************************************
    /**
     * @notice Function to add a new topic, can be called by anyone
     * 
     * @param topicView The topic data to add
     */
    function addTopic(
        TopicView calldata topicView
    ) external returns (uint256 newTopicId) {
        if (bytes(topicView.config.title).length == 0) {
            revert UpshotOracleV2InvalidTopicTitle();
        }
        newTopicId = nextTopicId++;

        topic[newTopicId].config = topicView.config;
        topic[newTopicId].config.recentValue = 0;
        topic[newTopicId].config.recentValueTime = 0;

        for (uint256 i = 0; i < topicView.validDataProviders.length;) {
            EnumerableSet.add(topic[newTopicId].validDataProviders, topicView.validDataProviders[i]);

            unchecked { ++i; }
        }

        emit UpshotOracleV2TopicAdded(topicView);
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
            revert UpshotOracleV2InvalidDataProviderQuorum();
        }

        topic[topicId].config.dataProviderQuorum = dataProviderQuorum;

        emit UpshotOracleV2OracleTopicOwnerUpdatedDataProviderQuorum(topicId, dataProviderQuorum);
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
            revert UpshotOracleV2InvalidDataValiditySeconds();
        }

        topic[topicId].config.dataValiditySeconds = dataValiditySeconds;

        emit UpshotOracleV2OracleTopicOwnerUpdatedDataValiditySeconds(topicId, dataValiditySeconds);
    }

    /**
     * @notice Topic owner function to update the total fee
     * 
     * @param topicId The topicId to update the total fee for
     * @param totalFee The total fee to be paid per piece of data
     */
    function updateTotalFee(uint256 topicId, uint128 totalFee) external onlyTopicOwner(topicId) {
        if (0 < totalFee && totalFee < 1_000) {
            revert UpshotOracleV2InvalidTotalFee();
        }
        topic[topicId].config.totalFee = totalFee;

        emit UpshotOracleV2OracleTopicOwnerUpdatedFee(totalFee);
    }

  /**
     * @notice Topic owner function to add a data provider
     * 
     * @param topicId The topicId to add the data provider to
     * @param dataProvider The data provider to add
     */
    function addDataProvider(uint256 topicId, address dataProvider) external onlyTopicOwner(topicId) {
        EnumerableSet.add(topic[topicId].validDataProviders, dataProvider);

        emit UpshotOracleV2OracleTopicOwnerAddedDataProvider(topicId, dataProvider);
    }

    /**
     * @notice Topic owner function to remove a data provider
     * 
     * @param topicId The topicId to remove the data provider from
     * @param dataProvider the data provider to remove
     */
    function removeDataProvider(uint256 topicId, address dataProvider) external onlyTopicOwner(topicId) {
        EnumerableSet.remove(topic[topicId].validDataProviders, dataProvider);

        emit UpshotOracleV2OracleTopicOwnerRemovedDataProvider(dataProvider);
    }

    /**
     * @notice Topic owner function to turn off a topic
     * 
     * @param topicId The topicId of the topic to turn off
     */
    function turnOffTopic(uint256 topicId) external onlyTopicOwner(topicId) {
        topic[topicId].config.ownerSwitchedOn = false;
        
        emit UpshotOracleV2OracleTopicOwnerTopicTurnedOff(topicId);
    }

    /**
     * @notice Topic owner function to turn on a topic
     * 
     * @param topicId The topicId of the topic to turn on
     */
    function turnOnTopic(uint256 topicId) external onlyTopicOwner(topicId) {
        topic[topicId].config.ownerSwitchedOn = true;
        
        emit UpshotOracleV2OracleTopicOwnerTopicTurnedOn(topicId);
    }

    /**
     * @notice Topic owner function to update the aggregator to use for aggregating numeric data
     * 
     * @param topicId The topicId to update the aggregator for
     * @param aggregator The aggregator to use for aggregating numeric data
     */
    function updateAggregator(uint256 topicId, IAggregator aggregator) external onlyTopicOwner(topicId) {
        if (address(aggregator) == address(0)) {
            revert UpshotOracleV2InvalidAggregator();
        }

        topic[topicId].config.aggregator = aggregator;

        emit UpshotOracleV2OracleTopicOwnerUpdatedAggregator(topicId, aggregator);
    }

    /**
     * @notice Topic owner function to update the fee handler to use for handling fees
     * 
     * @param topicId The topicId to update the fee handler for
     * @param feeHandler The fee handler to use for handling fees
     */
    function updateFeeHandler(uint256 topicId, IFeeHandler feeHandler) external onlyTopicOwner(topicId) {
        if (address(feeHandler) == address(0)) {
            revert UpshotOracleV2InvalidFeeHandler();
        }

        topic[topicId].config.feeHandler = feeHandler;

        emit UpshotOracleV2OracleTopicOwnerUpdatedFeeHandler(topicId, feeHandler);
    } 

    /**
     * @notice Topic owner function to update the owner of the topic 
     * 
     * @param topicId The topicId to update the fee handler for
     * @param owner_ The new owner of the topic
     */
    function updateTopicOwner(uint256 topicId, address owner_) external onlyTopicOwner(topicId) {
        topic[topicId].config.owner = owner_;

        emit UpshotOracleV2OracleTopicOwnerUpdatedOwner(topicId, owner_);
    } 

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************
    /**
     * @notice Admin function to switch off the oracle contract
     */
    function adminTurnOffOracle() external onlyOwner {
        switchedOn = false;

        emit UpshotOracleV2OracleAdminOracleTurnedOff();
    }

    /**
     * @notice Admin function to switch on the oracle contract
     */
    function adminTurnOnOracle() external onlyOwner {
        switchedOn = true;

        emit UpshotOracleV2OracleAdminOracleTurnedOn();
    }
    
    /**
     * @notice Admin function to turn off a topic
     * 
     * @param topicId The topicId of the topic to turn off
     */
    function adminTurnOffTopic(uint256 topicId) external onlyOwner {
        topic[topicId].config.adminSwitchedOn = false;
        
        emit UpshotOracleV2OracleAdminTopicTurnedOff(topicId);
    }

    /**
     * @notice Admin function to turn on a topic
     * 
     * @param topicId The topicId of the topic to turn on
     */
    function adminTurnOnTopic(uint256 topicId) external onlyOwner {
        topic[topicId].config.adminSwitchedOn = true;
        
        emit UpshotOracleV2OracleAdminTopicTurnedOn(topicId);
    }

    /**
     * @notice Admin function to update the portion of the total fee that goes to the protocol
     * 
     * @param protocolFee_ The new protocol fee
     */
    function adminSetProtocolFee(uint256 protocolFee_) external onlyOwner {
        if (protocolFee_ > 0.5 ether) {
            revert UpshotOracleV2ProtocolFeeTooHigh();
        }

        protocolFee = protocolFee_;

        emit UpshotOracleV2OracleAdminUpdatedProtocolFee(protocolFee_);
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
