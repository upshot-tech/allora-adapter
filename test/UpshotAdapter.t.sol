// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { UpshotAdapter, UpshotAdapterConstructorArgs } from "../src/UpshotAdapter.sol";
import { 
    SignedNumericData, 
    NumericData, 
    TopicView, 
    TopicConfig, 
    UpshotAdapterNumericData
} from "../src/interface/IUpshotAdapter.sol";
import { EvenFeeHandler, EvenFeeHandlerConstructorArgs } from "../src/feeHandler/EvenFeeHandler.sol";
import { AverageAggregator } from "../src/aggregator/AverageAggregator.sol";
import { MedianAggregator } from "../src/aggregator/MedianAggregator.sol";
import { IAggregator } from "../src/interface/IAggregator.sol";
import { IFeeHandler } from "../src/interface/IFeeHandler.sol";


contract UpshotAdapterTest is Test {

    IAggregator aggregator;
    EvenFeeHandler evenFeeHandler;
    UpshotAdapter upshotAdapter;

    address admin = address(100);
    address protocolFeeReceiver = address(101);
    address topicOwner = address(102);

    uint256 signer0pk = 0x1000;
    uint256 signer1pk = 0x1001;
    uint256 signer2pk = 0x1002;

    address signer0;
    address signer1;
    address signer2;

    address[] oneValidSigner;
    address[] twoValidSigners;
    address[] threeValidSigners;
    address[] emptyValidSigners;


    function setUp() public {
        vm.warp(1 hours);

        aggregator = new AverageAggregator();
        evenFeeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin
        }));
        upshotAdapter = new UpshotAdapter(UpshotAdapterConstructorArgs({
            admin: admin,
            protocolFeeReceiver: protocolFeeReceiver
        }));

        signer0 = vm.addr(signer0pk);
        signer1 = vm.addr(signer1pk);
        signer2 = vm.addr(signer2pk);

        oneValidSigner = new address[](1);
        oneValidSigner[0] = signer0;

        twoValidSigners = new address[](2);
        twoValidSigners[0] = signer0;
        twoValidSigners[1] = signer1;

        threeValidSigners = new address[](3);
        threeValidSigners[0] = signer0;
        threeValidSigners[1] = signer1;
        threeValidSigners[2] = signer2;
    }

    // ***************************************************************
    // * ===================== FUNCTIONALITY ======================= *
    // ***************************************************************
    function test_cantCallVerifyDataWhenContractSwitchedOff() public {
        vm.startPrank(admin);
        vm.deal(admin, 2^128);
        upshotAdapter.adminTurnOffAdapter();
        
        SignedNumericData[] memory numericData = new SignedNumericData[](0);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2NotSwitchedOn()"));
        upshotAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithoutFee() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InsufficientPayment()"));
        upshotAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithNoData() public {
        SignedNumericData[] memory numericData = new SignedNumericData[](0);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2NoDataProvided()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDAtaWithLessThanThresholdData() public {
        vm.startPrank(admin);
        TopicView memory topicView = _getBasicTopicView();
        topicView.config.dataProviderQuorum = 2;
        upshotAdapter.addTopic(topicView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2NotEnoughData()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_canCallVerifyDataWithValidSignature() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_canValueIsSavedWhenCallingVerifyDataWithValidSignature() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        uint48 timestamp = 1672527600;
        vm.warp(timestamp);

        uint256 recentValueTime0 = upshotAdapter.getTopicValue(1, '').recentValueTime;
        uint256 recentValue0 = upshotAdapter.getTopicValue(1, '').recentValue;

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        uint256 recentValueTime1 = upshotAdapter.getTopicValue(1, '').recentValueTime;
        uint256 recentValue1 = upshotAdapter.getTopicValue(1, '').recentValue;

        assertEq(recentValueTime0, 0);
        assertEq(recentValueTime1, timestamp);

        assertEq(recentValue0, 0);
        assertEq(recentValue1, 1 ether);
    }

    function test_cantCallVerifyDataWithoutValidTopicId() public {
        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OwnerTurnedTopicOff()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWhenTopicIsTurnedOffByOwner() public {
        vm.startPrank(topicOwner);
        uint topicId = upshotAdapter.addTopic(_getBasicTopicView());
        upshotAdapter.turnOffTopic(topicId);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: uint64(topicId),
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OwnerTurnedTopicOff()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWhenTopicIsTurnedOffByAdmin() public {
        vm.startPrank(topicOwner);
        uint topicId = upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        vm.startPrank(admin);
        upshotAdapter.adminTurnOffTopic(topicId);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: uint64(topicId),
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2AdminTurnedTopicOff()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithMismatchedTopics() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 2,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2TopicMismatch()"));

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithMismatchedExtraData() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: '2'
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2ExtraDataMismatch()"));

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithMismatchedExtraData2() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: '1'
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: '2'
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2ExtraDataMismatch()"));

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithFutureTime() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp + 1),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidDataTime()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithExpiredTime() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64((block.timestamp - upshotAdapter.getTopic(1).config.dataValiditySeconds) - 1),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidDataTime()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithInvalidDataProvider() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicViewNoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidDataProvider()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithDuplicateDataProvider() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2DuplicateDataProvider()"));
        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_dataAverageAggregationWorksCorrectly() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicViewTwoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        uint256 numericValue = upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(numericValue, 2 ether);
    }

    function test_valueIsSavedWhenCallingVerifyDataWithMultipleValidSignatures() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicViewTwoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);


        uint256 recentValue0 = upshotAdapter.getTopicValue(1, '').recentValue;

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        uint256 recentValue1 = upshotAdapter.getTopicValue(1, '').recentValue;

        assertEq(recentValue0, 0);
        assertEq(recentValue1, 2 ether);
    }

    function test_valueIsSavedWhenCallingVerifyDataWithExtraDataSet() public {
        vm.startPrank(admin);
        upshotAdapter.addTopic(_getBasicTopicViewTwoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);


        uint256 recentValueEmptyExtraData0 = upshotAdapter.getTopicValue(1, '').recentValue;
        uint256 recentValue0 = upshotAdapter.getTopicValue(1, '123').recentValue;

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: '123'
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: '123'
            }),
            signer1pk
        );

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        uint256 recentValueEmptyExtraData1 = upshotAdapter.getTopicValue(1, '').recentValue;
        uint256 recentValue1 = upshotAdapter.getTopicValue(1, '123').recentValue;

        assertEq(recentValueEmptyExtraData0, 0);
        assertEq(recentValueEmptyExtraData1, 0);
        assertEq(recentValue0, 0);
        assertEq(recentValue1, 2 ether);
    }


    function test_dataMedianAggregationWorksCorrectly() public {
        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);
        TopicView memory topicView = _getBasicTopicViewTwoDataProviders();
        topicView.config.aggregator = medianAggregator;
        upshotAdapter.addTopic(topicView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        uint256 price = upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(price, 2 ether);
    }

    function test_dataMedianAggregationWorksCorrectly2() public {
        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);

        TopicView memory topicView = _getBasicTopicViewThreeDataProviders();
        topicView.config.aggregator = medianAggregator;
        upshotAdapter.addTopic(topicView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](3);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 2 ether,
                extraData: ''
            }),
            signer1pk
        );

        numericData[2] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 5 ether,
                extraData: ''
            }),
            signer2pk
        );

        uint256 price = upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(price, 2 ether);
    }

    function test_dataAggregationWorksCorrectlyAfterUpdatingAggregator() public {
        uint256 topicId = upshotAdapter.addTopic(_getBasicTopicViewThreeDataProviders());

        SignedNumericData[] memory numericData = new SignedNumericData[](3);

        NumericData memory rawNumericData0 = NumericData({
            topicId: uint64(1),
            timestamp: uint64(block.timestamp - 1 minutes),
            numericValue: 1 ether,
            extraData: ''
        });

        NumericData memory rawNumericData1 = NumericData({
            topicId: uint64(1),
            timestamp: uint64(block.timestamp - 1 minutes),
            numericValue: 2 ether,
            extraData: ''
        });

        NumericData memory rawNumericData2 = NumericData({
            topicId: uint64(1),
            timestamp: uint64(block.timestamp - 1 minutes),
            numericValue: 6 ether,
            extraData: ''
        });

        numericData[0] = _signNumericData(rawNumericData0, signer0pk);
        numericData[1] = _signNumericData(rawNumericData1, signer1pk);
        numericData[2] = _signNumericData(rawNumericData2, signer2pk);

        uint256 numericValue = upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(numericValue, 3 ether);

        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(topicOwner);
        upshotAdapter.updateAggregator(topicId, medianAggregator);
        vm.stopPrank();

        numericData[0] = _signNumericData(rawNumericData0, signer0pk);
        numericData[1] = _signNumericData(rawNumericData1, signer1pk);
        numericData[2] = _signNumericData(rawNumericData2, signer2pk);

        uint256 numericValue2 = upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(numericValue2, 2 ether);
    }

    function test_dataFeesSplitCorrectly() public {
        vm.startPrank(topicOwner);
        upshotAdapter.addTopic(_getBasicTopicViewTwoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        assertEq(evenFeeHandler.feesAccrued(topicOwner), 0.2 ether);

        assertEq(evenFeeHandler.feesAccrued(signer0), 0.4 ether);
        assertEq(evenFeeHandler.feesAccrued(signer1), 0.4 ether);

    }

    function test_dataFeesSplitCorrectlyWithProtocol() public {
        vm.startPrank(topicOwner);
        upshotAdapter.addTopic(_getBasicTopicViewTwoDataProviders());
        vm.stopPrank();

        vm.startPrank(admin);
        upshotAdapter.adminSetProtocolFee(0.2 ether);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        upshotAdapter.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        assertEq(upshotAdapter.protocolFeeReceiver().balance, 0.2 ether);
        assertEq(evenFeeHandler.feesAccrued(topicOwner), 0.16 ether);

        assertEq(evenFeeHandler.feesAccrued(signer0), 0.32 ether);
        assertEq(evenFeeHandler.feesAccrued(signer1), 0.32 ether);

    }


    // ***************************************************************
    // * ================= INTERNAL HELPERS ======================== *
    // ***************************************************************
    function _signNumericData(
        NumericData memory numericData,
        uint256 signerPk
    ) internal view returns (SignedNumericData memory) {
        bytes32 message = upshotAdapter.getMessage(numericData);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPk, 
            ECDSA.toEthSignedMessageHash(message)
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        return SignedNumericData({
            signature: signature,
            numericData: numericData
        });
    }

    function _getBasicTopicView() internal view returns (TopicView memory topicView) {
        return TopicView({
            config: TopicConfig({
                title: 'Initial topic',
                owner: topicOwner,
                totalFee: 0.001 ether,
                aggregator: aggregator,
                ownerSwitchedOn: true,
                adminSwitchedOn: true,
                feeHandler: evenFeeHandler,
                dataProviderQuorum: 1,
                dataValiditySeconds: 5 minutes
            }),
            validDataProviders: oneValidSigner
        });
    }

    function _getBasicTopicViewNoDataProviders() internal view returns (TopicView memory topicView) {
        topicView = _getBasicTopicView();
        topicView.validDataProviders = emptyValidSigners;
    }

    function _getBasicTopicViewTwoDataProviders() internal view returns (TopicView memory topicView) {
        topicView = _getBasicTopicView();
        topicView.validDataProviders = twoValidSigners;
    }

    function _getBasicTopicViewThreeDataProviders() internal view returns (TopicView memory topicView) {
        topicView = _getBasicTopicView();
        topicView.validDataProviders = threeValidSigners;
    }

    function _packageNumericData(
        SignedNumericData[] memory numericData,
        bytes memory extraData
    ) internal pure returns (UpshotAdapterNumericData memory pd) {
        pd = UpshotAdapterNumericData({
            signedNumericData: numericData,
            extraData: extraData
        });
    }
}
