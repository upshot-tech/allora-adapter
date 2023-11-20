// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Oracle, OracleConstructorArgs } from "../src/Oracle.sol";
import { 
    SignedNumericData, 
    NumericData, 
    FeedView, 
    FeedConfig, 
    UpshotOracleNumericData
} from "../src/interface/IOracle.sol";
import { EvenFeeHandler, EvenFeeHandlerConstructorArgs } from "../src/feeHandler/EvenFeeHandler.sol";
import { AverageAggregator } from "../src/aggregator/AverageAggregator.sol";
import { MedianAggregator } from "../src/aggregator/MedianAggregator.sol";
import { IAggregator } from "../src/interface/IAggregator.sol";
import { IFeeHandler } from "../src/interface/IFeeHandler.sol";


contract OracleTest is Test {

    IAggregator aggregator;
    EvenFeeHandler evenFeeHandler;
    Oracle oracle;

    address admin = address(100);
    address protocolFeeReceiver = address(101);
    address feedOwner = address(102);

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
        oracle = new Oracle(OracleConstructorArgs({
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
        oracle.adminTurnOffOracle();
        
        SignedNumericData[] memory numericData = new SignedNumericData[](0);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2NotSwitchedOn()"));
        oracle.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithoutFee() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InsufficientPayment()"));
        oracle.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithNoData() public {
        SignedNumericData[] memory numericData = new SignedNumericData[](0);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2NoDataProvided()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDAtaWithLessThanThresholdData() public {
        vm.startPrank(admin);
        FeedView memory feedView = _getBasicFeedView();
        feedView.config.dataProviderQuorum = 2;
        oracle.addFeed(feedView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2NotEnoughData()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_canCallVerifyDataWithValidSignature() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_canValueIsSavedWhenCallingVerifyDataWithValidSignature() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        uint48 timestamp = 1672527600;
        vm.warp(timestamp);

        uint48 recentValueTime0 = oracle.getFeed(1).config.recentValueTime;
        uint256 recentValue0 = oracle.getFeed(1).config.recentValue;

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        uint48 recentValueTime1 = oracle.getFeed(1).config.recentValueTime;
        uint256 recentValue1 = oracle.getFeed(1).config.recentValue;

        assertEq(recentValueTime0, 0);
        assertEq(recentValueTime1, timestamp);

        assertEq(recentValue0, 0);
        assertEq(recentValue1, 1 ether);
    }

    function test_cantCallVerifyDataWithoutValidFeedId() public {
        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OwnerTurnedFeedOff()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWhenFeedIsTurnedOffByOwner() public {
        vm.startPrank(feedOwner);
        uint feedId = oracle.addFeed(_getBasicFeedView());
        oracle.turnOffFeed(feedId);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: uint64(feedId),
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OwnerTurnedFeedOff()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWhenFeedIsTurnedOffByAdmin() public {
        vm.startPrank(feedOwner);
        uint feedId = oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        vm.startPrank(admin);
        oracle.adminTurnOffFeed(feedId);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: uint64(feedId),
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2AdminTurnedFeedOff()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithMismatchedFeeds() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 2,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2FeedMismatch()"));

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithFutureTime() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp + 1),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidDataTime()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithExpiredTime() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64((block.timestamp - oracle.getFeed(1).config.dataValiditySeconds) - 1),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidDataTime()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithInvalidDataProvider() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedViewNoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidDataProvider()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithDuplicateDataProvider() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2DuplicateDataProvider()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_dataAverageAggregationWorksCorrectly() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedViewTwoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        uint256 numericValue = oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(numericValue, 2 ether);
    }

    function test_valueIsSavedWhenCallingVerifyDataWithMultipleValidSignatures() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedViewTwoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);


        uint256 recentValue0 = oracle.getFeed(1).config.recentValue;

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        uint256 recentValue1 = oracle.getFeed(1).config.recentValue;

        assertEq(recentValue0, 0);
        assertEq(recentValue1, 2 ether);
    }


    function test_dataMedianAggregationWorksCorrectly() public {
        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);
        FeedView memory feedView = _getBasicFeedViewTwoDataProviders();
        feedView.config.aggregator = medianAggregator;
        oracle.addFeed(feedView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        uint256 price = oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(price, 2 ether);
    }

    function test_dataMedianAggregationWorksCorrectly2() public {
        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);

        FeedView memory feedView = _getBasicFeedViewThreeDataProviders();
        feedView.config.aggregator = medianAggregator;
        oracle.addFeed(feedView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](3);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 2 ether,
                extraData: ''
            }),
            signer1pk
        );

        numericData[2] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 5 ether,
                extraData: ''
            }),
            signer2pk
        );

        uint256 price = oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(price, 2 ether);
    }

    function test_dataAggregationWorksCorrectlyAfterUpdatingAggregator() public {
        uint256 feedId = oracle.addFeed(_getBasicFeedViewThreeDataProviders());

        SignedNumericData[] memory numericData = new SignedNumericData[](3);

        NumericData memory rawNumericData0 = NumericData({
            feedId: uint64(1),
            timestamp: uint64(block.timestamp - 1 minutes),
            numericValue: 1 ether,
            extraData: ''
        });

        NumericData memory rawNumericData1 = NumericData({
            feedId: uint64(1),
            timestamp: uint64(block.timestamp - 1 minutes),
            numericValue: 2 ether,
            extraData: ''
        });

        NumericData memory rawNumericData2 = NumericData({
            feedId: uint64(1),
            timestamp: uint64(block.timestamp - 1 minutes),
            numericValue: 6 ether,
            extraData: ''
        });

        numericData[0] = _signNumericData(rawNumericData0, signer0pk);
        numericData[1] = _signNumericData(rawNumericData1, signer1pk);
        numericData[2] = _signNumericData(rawNumericData2, signer2pk);

        uint256 numericValue = oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(numericValue, 3 ether);

        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(feedOwner);
        oracle.updateAggregator(feedId, medianAggregator);
        vm.stopPrank();

        numericData[0] = _signNumericData(rawNumericData0, signer0pk);
        numericData[1] = _signNumericData(rawNumericData1, signer1pk);
        numericData[2] = _signNumericData(rawNumericData2, signer2pk);

        uint256 numericValue2 = oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(numericValue2, 2 ether);
    }

    function test_dataFeesSplitCorrectly() public {
        vm.startPrank(feedOwner);
        oracle.addFeed(_getBasicFeedViewTwoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        assertEq(evenFeeHandler.feesAccrued(feedOwner), 0.2 ether);

        assertEq(evenFeeHandler.feesAccrued(signer0), 0.4 ether);
        assertEq(evenFeeHandler.feesAccrued(signer1), 0.4 ether);

    }

    function test_dataFeesSplitCorrectlyWithProtocol() public {
        vm.startPrank(feedOwner);
        oracle.addFeed(_getBasicFeedViewTwoDataProviders());
        vm.stopPrank();

        vm.startPrank(admin);
        oracle.adminSetProtocolFee(0.2 ether);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        assertEq(oracle.protocolFeeReceiver().balance, 0.2 ether);
        assertEq(evenFeeHandler.feesAccrued(feedOwner), 0.16 ether);

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
        bytes32 message = oracle.getMessage(numericData);

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

    function _getBasicFeedView() internal view returns (FeedView memory feedView) {
        return FeedView({
            config: FeedConfig({
                title: 'Initial feed',
                owner: feedOwner,
                totalFee: 0.001 ether,
                recentValueTime: 0,
                recentValue: 0,
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

    function _getBasicFeedViewNoDataProviders() internal view returns (FeedView memory feedView) {
        feedView = _getBasicFeedView();
        feedView.validDataProviders = emptyValidSigners;
    }

    function _getBasicFeedViewTwoDataProviders() internal view returns (FeedView memory feedView) {
        feedView = _getBasicFeedView();
        feedView.validDataProviders = twoValidSigners;
    }

    function _getBasicFeedViewThreeDataProviders() internal view returns (FeedView memory feedView) {
        feedView = _getBasicFeedView();
        feedView.validDataProviders = threeValidSigners;
    }

    function _packageNumericData(
        SignedNumericData[] memory numericData,
        bytes memory extraData
    ) internal pure returns (UpshotOracleNumericData memory pd) {
        pd = UpshotOracleNumericData({
            signedNumericData: numericData,
            extraData: extraData
        });
    }
}
