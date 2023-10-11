// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Oracle, OracleConstructorArgs } from "../src/Oracle.sol";
import { SignedNumericData, NumericData, FeedView, UpshotOracleNumericData } from "../src/interface/IOracle.sol";
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
            admin: admin,
            protocolFeeReceiver: protocolFeeReceiver
        }));
        oracle = new Oracle(OracleConstructorArgs({
            admin: admin 
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
        oracle.turnOff();
        
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
                nonce: 2,
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
        feedView.dataProviderQuorum = 2;
        oracle.addFeed(feedView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
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
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithoutValidFeedId() public {
        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeed()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithoutValidNonce() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 3,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidNonce()"));
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
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 2,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2FeedMismatch()"));

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithMismatchedNonces() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 3,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2NonceMismatch()"));
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
                nonce: 2,
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
                timestamp: uint64((block.timestamp - oracle.getFeed(1).dataValiditySeconds) - 1),
                nonce: 2,
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
                nonce: 2,
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
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2DuplicateDataProvider()"));
        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
    }

    function test_validatingANewPriceIncrementsNonceForTheFeed() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedViewTwoDataProviders());
        vm.stopPrank();

        uint256 nonce0 = oracle.getFeed(1).nonce;

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        uint256 nonce1 = oracle.getFeed(1).nonce;

        assertEq(nonce1, nonce0 + 1);
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
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        uint256 numericValue = oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(numericValue, 2 ether);
    }

    function test_dataMedianAggregationWorksCorrectly() public {
        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);
        FeedView memory feedView = _getBasicFeedViewTwoDataProviders();
        feedView.aggregator = medianAggregator;
        oracle.addFeed(feedView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
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
        feedView.aggregator = medianAggregator;
        oracle.addFeed(feedView);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](3);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 2 ether,
                extraData: ''
            }),
            signer1pk
        );

        numericData[2] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 5 ether,
                extraData: ''
            }),
            signer2pk
        );

        uint256 price = oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));
        assertEq(price, 2 ether);
    }

    function test_dataFeesSplitCorrectly() public {
        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedViewTwoDataProviders());
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        numericData[0] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        numericData[1] = _signNumericData(
            NumericData({
                feedId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                nonce: 2,
                numericValue: 3 ether,
                extraData: ''
            }),
            signer1pk
        );

        oracle.verifyData{value: 1 ether}(_packageNumericData(numericData, ''));

        assertEq(evenFeeHandler.feesAccrued(protocolFeeReceiver), 0.2 ether);

        assertEq(evenFeeHandler.feesAccrued(signer0), 0.4 ether);
        assertEq(evenFeeHandler.feesAccrued(signer1), 0.4 ether);

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
            title: 'Initial feed',
            nonce: 1,
            totalFee: 0.001 ether,
            dataProviderQuorum: 1,
            dataValiditySeconds: 5 minutes,
            aggregator: aggregator,
            isValid: true,
            feeHandler: evenFeeHandler,
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
