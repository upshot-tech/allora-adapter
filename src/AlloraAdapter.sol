// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;


import { IAggregator } from './interface/IAggregator.sol';
import { IFeeHandler } from './interface/IFeeHandler.sol';
import { AlloraAdapterNumericData, NumericData, IAlloraAdapter, TopicValue } from './interface/IAlloraAdapter.sol';
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EIP712 } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

struct AlloraAdapterConstructorArgs {
    address owner;
    IAggregator aggregator;
}


contract AlloraAdapter is IAlloraAdapter, Ownable2Step, EIP712 {

    /// @dev The value for each topic
    mapping(uint256 topicId => mapping(bytes extraData => TopicValue)) public topicValue;

    /// @dev Whether the AlloraAdapter contract is switched on and usable
    bool public switchedOn = true;

    mapping(address dataProvider => bool) public validDataProvider;

    bytes32 public constant NUMERIC_DATA_TYPEHASH = keccak256(
        "NumericData(uint256 topicId,uint256 timestamp,uint256 numericValue,bytes extraData)"
    );

    IAggregator public aggregator;

    uint48 public dataValiditySeconds = 1 hours;

    constructor(AlloraAdapterConstructorArgs memory args) 
        EIP712("AlloraAdapter", "1") 
    {
        _transferOwnership(args.owner);

        aggregator = args.aggregator;
    }

    // ***************************************************************
    // * ========================= EVENTS ========================== *
    // ***************************************************************

    // main interface events
    event AlloraAdapterV2AdapterVerifiedData(uint256 topicId, uint256 numericData, address dataProvider, bytes extraData);

    // adapter admin updates
    event AlloraAdapterV2AdapterAdminTurnedOff();
    event AlloraAdapterV2AdapterAdminTurnedOn();
    event AlloraAdapterV2AdapterOwnerAddedDataProvider(address dataProvider);
    event AlloraAdapterV2AdapterOwnerRemovedDataProvider(address dataProvider);
    event AlloraAdapterV2AdapterOwnerUpdatedDataValiditySeconds(uint48 dataValiditySeconds);
    event AlloraAdapterV2AdapterOwnerUpdatedAggregator(IAggregator aggregator);

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    // verification errors
    error AlloraAdapterV2NotSwitchedOn();
    error AlloraAdapterV2NoDataProvided();
    error AlloraAdapterV2TopicMismatch();
    error AlloraAdapterV2ExtraDataMismatch();
    error AlloraAdapterV2InvalidDataTime();
    error AlloraAdapterV2InvalidDataProvider();
    error AlloraAdapterV2DuplicateDataProvider();

    // parameter update errors
    error AlloraAdapterV2InvalidAggregator();
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
        address dataProvider, 
        bytes memory extraData
    ) {
        (numericValue, topicId, dataProvider, extraData) = _verifyData(nd);

        topicValue[topicId][extraData] = TopicValue({
            recentValue: _toUint192(numericValue),
            recentValueTime: _toUint64(block.timestamp)
        });

        emit AlloraAdapterV2AdapterVerifiedData(topicId, numericValue, dataProvider, extraData);
    }

    ///@inheritdoc IAlloraAdapter
    function verifyDataViewOnly(
        AlloraAdapterNumericData memory nd
    ) external view override returns (
        uint256 numericValue, 
        uint256 topicId, 
        address dataProvider, 
        bytes memory extraData
    ) {
        (numericValue, topicId, dataProvider, extraData) = _verifyData(nd);
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
        address dataProvider, 
        bytes memory extraData
    ) {
        if (!switchedOn) {
            revert AlloraAdapterV2NotSwitchedOn();
        }

        dataProvider = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(getMessage(nd.numericData)), 
            nd.signature
        );

        if (!_isOwnerOrValidDataProvider(dataProvider)) {
            revert AlloraAdapterV2InvalidDataProvider();
        }

        uint256 dataCount = nd.numericData.length;

        if (dataCount == 0) {
            revert AlloraAdapterV2NoDataProvided();
        }

        topicId = nd.numericData[0].topicId;
        extraData = nd.numericData[0].extraData;

        uint256[] memory dataList = new uint256[](dataCount);
        NumericData memory _nd;
        uint64 _dataValiditySeconds = dataValiditySeconds;

        for(uint256 i = 0; i < dataCount;) {
            _nd = nd.numericData[i];

            if (_nd.topicId != topicId) {
                revert AlloraAdapterV2TopicMismatch();
            }

            if (!_equalBytes(_nd.extraData, extraData)) {
                revert AlloraAdapterV2ExtraDataMismatch();
            }

            if (
                block.timestamp < _nd.timestamp ||
                _nd.timestamp + _dataValiditySeconds < block.timestamp
            ) {
                revert AlloraAdapterV2InvalidDataTime();
            }

            dataList[i] = _nd.numericValue;

            unchecked {
                ++i;
            }
        }

        numericValue = aggregator.aggregate(dataList, nd.extraData);
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
        NumericData[] memory numericData
    ) public view returns (bytes32) {
        bytes memory encodedData = abi.encode(
            keccak256("NumericData(uint256 topicId,uint256 timestamp,uint256 numericValue,bytes extraData)"),
            _encodeNumericDataArray(numericData)
        );

         return _hashTypedDataV4(keccak256(encodedData));
    }

    function _encodeNumericDataArray(NumericData[] memory numericData) private pure returns (bytes memory) {
        bytes memory dataArray;
        for (uint i = 0; i < numericData.length;) {
            dataArray = abi.encodePacked(dataArray, abi.encode(
                numericData[i].topicId,
                numericData[i].timestamp,
                numericData[i].numericValue,
                keccak256(numericData[i].extraData) // Hash the extraData since it's dynamic
            ));

            unchecked {
                ++i;
            }
        }
        return dataArray;
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
    // * ========================= ADMIN =========================== *
    // ***************************************************************
    /**
     * @notice Admin function to switch off the adapter contract
     */
    function turnOffAdapter() external onlyOwner {
        switchedOn = false;

        emit AlloraAdapterV2AdapterAdminTurnedOff();
    }

    /**
     * @notice Admin function to switch on the adapter contract
     */
    function turnOnAdapter() external onlyOwner {
        switchedOn = true;

        emit AlloraAdapterV2AdapterAdminTurnedOn();
    }

    /**
     * @notice Topic owner function to update the number of seconds data is valid for
     * 
     * @param _dataValiditySeconds The number of seconds data is valid for
     */
    function updateDataValiditySeconds(
        uint48 _dataValiditySeconds
    ) external onlyOwner {
        if (_dataValiditySeconds == 0) { 
            revert AlloraAdapterV2InvalidDataValiditySeconds();
        }

        dataValiditySeconds = _dataValiditySeconds;

        emit AlloraAdapterV2AdapterOwnerUpdatedDataValiditySeconds(dataValiditySeconds);
    }

    /**
     * @notice Topic owner function to update the aggregator to use for aggregating numeric data
     * 
     * @param _aggregator The aggregator to use for aggregating numeric data
     */
    function updateAggregator(IAggregator _aggregator) external onlyOwner {
        if (address(_aggregator) == address(0)) {
            revert AlloraAdapterV2InvalidAggregator();
        }

        aggregator = _aggregator;

        emit AlloraAdapterV2AdapterOwnerUpdatedAggregator(aggregator);
    }

    /**
     * @notice Topic owner function to add a data provider
     * 
     * @param dataProvider The data provider to add
     */
    function addDataProvider(address dataProvider) external onlyOwner {
        validDataProvider[dataProvider] = true;

        emit AlloraAdapterV2AdapterOwnerAddedDataProvider(dataProvider);
    }

    /**
     * @notice Topic owner function to remove a data provider
     * 
     * @param dataProvider the data provider to remove
     */
    function removeDataProvider(address dataProvider) external onlyOwner {
        validDataProvider[dataProvider] = false;

        emit AlloraAdapterV2AdapterOwnerRemovedDataProvider(dataProvider);
    }

    // ***************************************************************
    // * ==================== INTERNAL HELPERS ===================== *
    // ***************************************************************
    /**
     * @notice Check if the data provider is valid or the owner
     * 
     * @param dataProvider The data provider to check
     * @return Whether the data provider is valid or the owner
     */
    function _isOwnerOrValidDataProvider(address dataProvider) internal view returns (bool) {
        return dataProvider == owner() || validDataProvider[dataProvider];
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
}
