// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { AlloraAdapter, AlloraAdapterConstructorArgs } from "../src/AlloraAdapter.sol";
import { 
    SignedNumericData, 
    NumericData, 
    AlloraAdapterNumericData
} from "../src/interface/IAlloraAdapter.sol";
import { AverageAggregator } from "../src/aggregator/AverageAggregator.sol";
import { MedianAggregator } from "../src/aggregator/MedianAggregator.sol";
import { IAggregator } from "../src/interface/IAggregator.sol";
import { IFeeHandler } from "../src/interface/IFeeHandler.sol";


contract AlloraAdapterTest is Test {

    IAggregator aggregator;
    AlloraAdapter alloraAdapter;

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
        alloraAdapter = new AlloraAdapter(AlloraAdapterConstructorArgs({
            owner: admin,
            aggregator: aggregator
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
        alloraAdapter.turnOffAdapter();
        
        SignedNumericData[] memory numericData = new SignedNumericData[](0);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2NotSwitchedOn()"));
        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithNoData() public {
        SignedNumericData[] memory numericData = new SignedNumericData[](0);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2NoDataProvided()"));
        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_canCallVerifyDataWithValidSignature() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
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

        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_valueIsSavedWhenCallingVerifyDataWithValidSignature() public {
        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        vm.stopPrank();

        uint48 timestamp = 1672527600;
        vm.warp(timestamp);

        uint256 recentValueTime0 = alloraAdapter.getTopicValue(1, '').recentValueTime;
        uint256 recentValue0 = alloraAdapter.getTopicValue(1, '').recentValue;

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64(block.timestamp - 1 minutes),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        alloraAdapter.verifyData(_packageNumericData(numericData, ''));

        uint256 recentValueTime1 = alloraAdapter.getTopicValue(1, '').recentValueTime;
        uint256 recentValue1 = alloraAdapter.getTopicValue(1, '').recentValue;

        assertEq(recentValueTime0, 0);
        assertEq(recentValueTime1, timestamp);

        assertEq(recentValue0, 0);
        assertEq(recentValue1, 1 ether);
    }

    function test_canCallVerifyDataWithoutValidTopicId() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
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

        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithMismatchedTopics() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
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

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2TopicMismatch()"));

        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithMismatchedExtraData() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
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

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2ExtraDataMismatch()"));

        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithMismatchedExtraData2() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
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

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2ExtraDataMismatch()"));

        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithFutureTime() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
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

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataTime()"));
        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithExpiredTime() public {
        vm.startPrank(admin);
        alloraAdapter.updateDataValiditySeconds(30 minutes);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](1);

        numericData[0] = _signNumericData(
            NumericData({
                topicId: 1,
                timestamp: uint64((block.timestamp - alloraAdapter.dataValiditySeconds()) - 1),
                numericValue: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataTime()"));
        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithInvalidDataProvider() public {
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

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataProvider()"));
        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_cantCallVerifyDataWithDuplicateDataProvider() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
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

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2DuplicateDataProvider()"));
        alloraAdapter.verifyData(_packageNumericData(numericData, ''));
    }

    function test_dataAverageAggregationWorksCorrectly() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
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

        (uint256 numericValue,,,) = alloraAdapter.verifyData(_packageNumericData(numericData, ''));
        assertEq(numericValue, 2 ether);
    }

    function test_viewAndNonViewFunctionsGiveSameResult() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
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

        (uint256 numericValue,,,) = alloraAdapter.verifyData(_packageNumericData(numericData, ''));
        (uint256 numericValueView,,,) = alloraAdapter.verifyDataViewOnly(_packageNumericData(numericData, ''));
        assertEq(numericValue, 2 ether);
        assertEq(numericValue, numericValueView);
    }

    function test_valueIsSavedWhenCallingVerifyDataWithMultipleValidSignatures() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        uint256 recentValue0 = alloraAdapter.getTopicValue(1, '').recentValue;

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

        alloraAdapter.verifyData(_packageNumericData(numericData, ''));

        uint256 recentValue1 = alloraAdapter.getTopicValue(1, '').recentValue;

        assertEq(recentValue0, 0);
        assertEq(recentValue1, 2 ether);
    }

    function test_valueIsSavedWhenCallingVerifyDataWithExtraDataSet() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        vm.stopPrank();

        SignedNumericData[] memory numericData = new SignedNumericData[](2);

        uint256 recentValueEmptyExtraData0 = alloraAdapter.getTopicValue(1, '').recentValue;
        uint256 recentValue0 = alloraAdapter.getTopicValue(1, '123').recentValue;

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

        alloraAdapter.verifyData(_packageNumericData(numericData, ''));

        uint256 recentValueEmptyExtraData1 = alloraAdapter.getTopicValue(1, '').recentValue;
        uint256 recentValue1 = alloraAdapter.getTopicValue(1, '123').recentValue;

        assertEq(recentValueEmptyExtraData0, 0);
        assertEq(recentValueEmptyExtraData1, 0);
        assertEq(recentValue0, 0);
        assertEq(recentValue1, 2 ether);
    }


    function test_dataMedianAggregationWorksCorrectly() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        vm.stopPrank();

        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);
        alloraAdapter.updateAggregator(medianAggregator);
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

        (uint256 numericValue,,,) = alloraAdapter.verifyData(_packageNumericData(numericData, ''));
        assertEq(numericValue, 2 ether);
    }

    function test_dataMedianAggregationWorksCorrectly2() public {
        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);
        alloraAdapter.updateAggregator(medianAggregator);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        alloraAdapter.addDataProvider(signer2);
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

        (uint256 numericValue,,,) = alloraAdapter.verifyData(_packageNumericData(numericData, ''));
        assertEq(numericValue, 2 ether);
    }

    function test_dataAggregationWorksCorrectlyAfterUpdatingAggregator() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        alloraAdapter.addDataProvider(signer2);
        vm.stopPrank();

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

        (uint256 numericValue,,,) = alloraAdapter.verifyData(_packageNumericData(numericData, ''));
        assertEq(numericValue, 3 ether);

        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);
        alloraAdapter.updateAggregator(medianAggregator);
        vm.stopPrank();

        numericData[0] = _signNumericData(rawNumericData0, signer0pk);
        numericData[1] = _signNumericData(rawNumericData1, signer1pk);
        numericData[2] = _signNumericData(rawNumericData2, signer2pk);

        (uint256 numericValue2,,,) = alloraAdapter.verifyData(_packageNumericData(numericData, ''));
        assertEq(numericValue2, 2 ether);
    }

    // ***************************************************************
    // * ================= INTERNAL HELPERS ======================== *
    // ***************************************************************
    function _signNumericData(
        NumericData memory numericData,
        uint256 signerPk
    ) internal view returns (SignedNumericData memory) {
        bytes32 message = alloraAdapter.getMessage(numericData);

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

    function _packageNumericData(
        SignedNumericData[] memory numericData,
        bytes memory extraData
    ) internal pure returns (AlloraAdapterNumericData memory pd) {
        pd = AlloraAdapterNumericData({
            signedNumericData: numericData,
            extraData: extraData
        });
    }
}
