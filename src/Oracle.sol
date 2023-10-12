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
    address protocolFeeReceiver;
}

contract Oracle is IOracle, Ownable2Step {

    /// @dev The data for each feed. Call getFeed function for access to structured data
    mapping(uint256 feedId => Feed) internal feed;

    /// @dev The next feedId to use
    uint256 public nextFeedId = 1;

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
    event UpshotOracleV2OracleVerifiedData(
        uint256 feedId, 
        uint256 numericData, 
        address[] dataProviders, 
        uint128 nonce
    );
    
    // feed owner update events
    event UpshotOracleV2FeedAdded(FeedView feedView);
    event UpshotOracleV2OracleFeedOwnerUpdatedDataProviderQuorum(uint256 feedId, uint48 dataProviderQuorum);
    event UpshotOracleV2OracleFeedOwnerUpdatedDataValiditySeconds(uint256 feedId, uint48 dataValiditySeconds);
    event UpshotOracleV2OracleFeedOwnerAddedDataProvider(uint256 feedId, address dataProvider);
    event UpshotOracleV2OracleFeedOwnerRemovedDataProvider(address dataProvider);
    event UpshotOracleV2OracleFeedOwnerUpdatedAggregator(uint256 feedId, IAggregator aggregator);
    event UpshotOracleV2OracleFeedOwnerUpdatedFeeHandler(uint256 feedId, IFeeHandler feeHandler);
    event UpshotOracleV2OracleFeedOwnerUpdatedFee(uint128 totalFee);
    event UpshotOracleV2OracleFeedOwnerUpdatedOwner(uint256 feedId, address newOwner);
    event UpshotOracleV2OracleFeedOwnerFeedTurnedOff(uint256 feedId);
    event UpshotOracleV2OracleFeedOwnerFeedTurnedOn(uint256 feedId);

    // oracle admin updates
    event UpshotOracleV2OracleAdminUpdatedProtocolFee(uint256 newProtocolFee);
    event UpshotOracleV2OracleAdminUpdatedProtocolFeeReceiver(address protocolFeeReceiver);
    event UpshotOracleV2OracleAdminFeedTurnedOff(uint256 feedId);
    event UpshotOracleV2OracleAdminFeedTurnedOn(uint256 feedId);
    event UpshotOracleV2OracleAdminOracleTurnedOff();
    event UpshotOracleV2OracleAdminOracleTurnedOn();

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    // verification errors
    error UpshotOracleV2NotSwitchedOn();
    error UpshotOracleV2NoDataProvided();
    error UpshotOracleV2OwnerTurnedFeedOff();
    error UpshotOracleV2AdminTurnedFeedOff();
    error UpshotOracleV2InsufficientPayment();
    error UpshotOracleV2NotEnoughData();
    error UpshotOracleV2FeedMismatch();
    error UpshotOracleV2NonceMismatch();
    error UpshotOracleV2InvalidDataTime();
    error UpshotOracleV2InvalidDataProvider();
    error UpshotOracleV2DuplicateDataProvider();
    error UpshotOracleV2InvalidNonce();
    error UpshotOracleV2EthTransferFailed();

    // parameter update errors
    error UpshotOracleV2InvalidFeedTitle();
    error UpshotOracleV2OnlyFeedOwner();
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

        uint256 feedId = nd.signedNumericData[0].numericData.feedId;

        if (!feed[feedId].config.ownerSwitchedOn) {
            revert UpshotOracleV2OwnerTurnedFeedOff();
        }

        if (!feed[feedId].config.adminSwitchedOn) {
            revert UpshotOracleV2AdminTurnedFeedOff();
        }

        // load once to save gas
        uint256 _protocolFee = protocolFee;

        if (msg.value < feed[feedId].config.totalFee + _protocolFee) {
            revert UpshotOracleV2InsufficientPayment();
        }

        if (dataCount < feed[feedId].config.dataProviderQuorum) {
            revert UpshotOracleV2NotEnoughData();
        }

        uint96 nonce = nd.signedNumericData[0].numericData.nonce;
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
                numericData.timestamp + feed[feedId].config.dataValiditySeconds < block.timestamp
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

        numericValue = feed[feedId].config.aggregator.aggregate(dataList, nd.extraData);

        if (_protocolFee != 0) {
            _safeTransferETH(protocolFeeReceiver, _protocolFee);
        }

        feed[feedId].config.feeHandler.handleFees{value: msg.value - _protocolFee}(
            feed[feedId].config.owner,
            dataProviders, 
            nd.extraData
        );

        emit UpshotOracleV2OracleVerifiedData(feedId, numericValue, dataProviders, nonce);
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
            numericData.feedId,
            numericData.nonce,
            numericData.timestamp,
            numericData.numericValue, 
            numericData.extraData
        ));
    }

    /**
     * @notice Get the feed data for a given feedId
     * 
     * @param feedId The feedId to get the feed data for
     * @return feedView The feed data
     */
    function getFeed(uint256 feedId) external view returns (FeedView memory feedView) {
        feedView = FeedView({
            config: feed[feedId].config,
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
    function _validateNonce(uint256 feedId, uint96 nonce) internal {
        if (nonce != feed[feedId].config.nonce + 1) {
            revert UpshotOracleV2InvalidNonce();
        }

        feed[feedId].config.nonce = nonce;
    }

    /**
     * @dev Modifier to check that the caller is the owner of the feed
     * 
     * @param feedId The feedId to validate the owner for
     */
    modifier onlyFeedOwner(uint256 feedId) {
        if (msg.sender != feed[feedId].config.owner) {
            revert UpshotOracleV2OnlyFeedOwner();
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
     * @dev Update the protocol fee receiver
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
     * @notice Function to add a new feed, can be called by anyone
     * 
     * @param feedView The feed data to add
     */
    function addFeed(
        FeedView calldata feedView
    ) external returns (uint256 newFeedId) {
        if (bytes(feedView.config.title).length == 0) {
            revert UpshotOracleV2InvalidFeedTitle();
        }
        newFeedId = nextFeedId++;

        feed[newFeedId].config = feedView.config;
        feed[newFeedId].config.nonce = 1;

        for (uint256 i = 0; i < feedView.validDataProviders.length;) {
            EnumerableSet.add(feed[newFeedId].validDataProviders, feedView.validDataProviders[i]);

            unchecked { ++i; }
        }

        emit UpshotOracleV2FeedAdded(feedView);
    }

    /**
     * @notice Feed owner function to update the minimum number of data providers needed to verify data
     * 
     * @param feedId The feedId to update the minimum number of data providers required
     * @param dataProviderQuorum The minimum number of data providers required
     */
    function updateDataProviderQuorum(
        uint256 feedId, 
        uint48 dataProviderQuorum
    ) external onlyFeedOwner(feedId) {
        if (dataProviderQuorum == 0) {
            revert UpshotOracleV2InvalidDataProviderQuorum();
        }

        feed[feedId].config.dataProviderQuorum = dataProviderQuorum;

        emit UpshotOracleV2OracleFeedOwnerUpdatedDataProviderQuorum(feedId, dataProviderQuorum);
    }

    /**
     * @notice Feed owner function to update the number of seconds data is valid for
     * 
     * @param feedId The feedId to update the number of seconds data is valid for
     * @param dataValiditySeconds The number of seconds data is valid for
     */
    function updateDataValiditySeconds(
        uint256 feedId, 
        uint48 dataValiditySeconds
    ) external onlyFeedOwner(feedId) {
        if (dataValiditySeconds == 0) { 
            revert UpshotOracleV2InvalidDataValiditySeconds();
        }

        feed[feedId].config.dataValiditySeconds = dataValiditySeconds;

        emit UpshotOracleV2OracleFeedOwnerUpdatedDataValiditySeconds(feedId, dataValiditySeconds);
    }

    /**
     * @notice Feed owner function to update the total fee
     * 
     * @param feedId The feedId to update the total fee for
     * @param totalFee The total fee to be paid per piece of data
     */
    function updateTotalFee(uint256 feedId, uint128 totalFee) external onlyFeedOwner(feedId) {
        if (0 < totalFee && totalFee < 1_000) {
            revert UpshotOracleV2InvalidTotalFee();
        }
        feed[feedId].config.totalFee = totalFee;

        emit UpshotOracleV2OracleFeedOwnerUpdatedFee(totalFee);
    }

  /**
     * @notice Feed owner function to add a data provider
     * 
     * @param feedId The feedId to add the data provider to
     * @param dataProvider The data provider to add
     */
    function addDataProvider(uint256 feedId, address dataProvider) external onlyFeedOwner(feedId) {
        EnumerableSet.add(feed[feedId].validDataProviders, dataProvider);

        emit UpshotOracleV2OracleFeedOwnerAddedDataProvider(feedId, dataProvider);
    }

    /**
     * @notice Feed owner function to remove a data provider
     * 
     * @param feedId The feedId to remove the data provider from
     * @param dataProvider the data provider to remove
     */
    function removeDataProvider(uint256 feedId, address dataProvider) external onlyFeedOwner(feedId) {
        EnumerableSet.remove(feed[feedId].validDataProviders, dataProvider);

        emit UpshotOracleV2OracleFeedOwnerRemovedDataProvider(dataProvider);
    }

    /**
     * @notice Feed owner function to turn off a feed
     * 
     * @param feedId The feedId of the feed to turn off
     */
    function turnOffFeed(uint256 feedId) external onlyFeedOwner(feedId) {
        feed[feedId].config.ownerSwitchedOn = false;
        
        emit UpshotOracleV2OracleFeedOwnerFeedTurnedOff(feedId);
    }

    /**
     * @notice Feed owner function to turn on a feed
     * 
     * @param feedId The feedId of the feed to turn on
     */
    function turnOnFeed(uint256 feedId) external onlyFeedOwner(feedId) {
        feed[feedId].config.ownerSwitchedOn = true;
        
        emit UpshotOracleV2OracleFeedOwnerFeedTurnedOn(feedId);
    }

    /**
     * @notice Feed owner function to update the aggregator to use for aggregating numeric data
     * 
     * @param feedId The feedId to update the aggregator for
     * @param aggregator The aggregator to use for aggregating numeric data
     */
    function updateAggregator(uint256 feedId, IAggregator aggregator) external onlyFeedOwner(feedId) {
        if (address(aggregator) == address(0)) {
            revert UpshotOracleV2InvalidAggregator();
        }

        feed[feedId].config.aggregator = aggregator;

        emit UpshotOracleV2OracleFeedOwnerUpdatedAggregator(feedId, aggregator);
    }

    /**
     * @notice Feed owner function to update the fee handler to use for handling fees
     * 
     * @param feedId The feedId to update the fee handler for
     * @param feeHandler The fee handler to use for handling fees
     */
    function updateFeeHandler(uint256 feedId, IFeeHandler feeHandler) external onlyFeedOwner(feedId) {
        if (address(feeHandler) == address(0)) {
            revert UpshotOracleV2InvalidFeeHandler();
        }

        feed[feedId].config.feeHandler = feeHandler;

        emit UpshotOracleV2OracleFeedOwnerUpdatedFeeHandler(feedId, feeHandler);
    } 

    /**
     * @notice Feed owner function to update the owner of the feed 
     * 
     * @param feedId The feedId to update the fee handler for
     * @param owner_ The new owner of the feed
     */
    function updateFeedOwner(uint256 feedId, address owner_) external onlyFeedOwner(feedId) {
        feed[feedId].config.owner = owner_;

        emit UpshotOracleV2OracleFeedOwnerUpdatedOwner(feedId, owner_);
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
     * @notice Admin function to turn off a feed
     * 
     * @param feedId The feedId of the feed to turn off
     */
    function adminTurnOffFeed(uint256 feedId) external onlyOwner {
        feed[feedId].config.adminSwitchedOn = false;
        
        emit UpshotOracleV2OracleAdminFeedTurnedOff(feedId);
    }

    /**
     * @notice Admin function to turn on a feed
     * 
     * @param feedId The feedId of the feed to turn on
     */
    function adminTurnOnFeed(uint256 feedId) external onlyOwner {
        feed[feedId].config.adminSwitchedOn = true;
        
        emit UpshotOracleV2OracleAdminFeedTurnedOn(feedId);
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
