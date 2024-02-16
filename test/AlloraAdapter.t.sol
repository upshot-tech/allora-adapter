// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { AlloraAdapter, AlloraAdapterConstructorArgs } from "../src/AlloraAdapter.sol";
import { 
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
        alloraAdapter.turnOffAdapter();
        
        AlloraAdapterNumericData memory nd = _packageAndSignNumericData(_dummyNumericData(), signer0pk);
        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2NotSwitchedOn()"));
        alloraAdapter.verifyData(nd);
    }

    function test_cantCallVerifyDataWithNoData() public {
        NumericData memory nd = _dummyNumericData();

        nd.numericValues = new uint256[](0);

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);
        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2NoDataProvided()"));
        alloraAdapter.verifyData(alloraNd);
    }

    function test_canCallVerifyDataWithValidSignature() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        vm.stopPrank();

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(_dummyNumericData(), signer0pk);  
        alloraAdapter.verifyData(alloraNd);
    }

    function test_valueIsSavedWhenCallingVerifyDataWithValidSignature() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        vm.stopPrank();

        uint48 timestamp = 1672527600;
        vm.warp(timestamp);

        NumericData memory nd = _dummyNumericData();
        nd.timestamp = uint64(block.timestamp - 1 minutes);

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);

        uint256 recentValueTime0 = alloraAdapter.getTopicValue(1, '').recentValueTime;
        uint256 recentValue0 = alloraAdapter.getTopicValue(1, '').recentValue;

        alloraAdapter.verifyData(alloraNd);

        uint256 recentValueTime1 = alloraAdapter.getTopicValue(1, '').recentValueTime;
        uint256 recentValue1 = alloraAdapter.getTopicValue(1, '').recentValue;

        assertEq(recentValue0, 0);
        assertEq(recentValueTime0, 0);

        assertEq(recentValue1, nd.numericValues[0]);
        assertEq(recentValueTime1, timestamp);
    }


    function test_cantCallVerifyDataWithFutureTime() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        vm.stopPrank();

        NumericData memory nd = _dummyNumericData();
        nd.timestamp = uint64(block.timestamp + 1 minutes);

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataTime()"));
        alloraAdapter.verifyData(alloraNd);
    }


    function test_cantCallVerifyDataWithExpiredTime() public {
        vm.startPrank(admin);
        alloraAdapter.updateDataValiditySeconds(30 minutes);
        vm.stopPrank();

        NumericData memory nd = _dummyNumericData();
        nd.timestamp = uint64((block.timestamp - alloraAdapter.dataValiditySeconds()) - 1);

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataTime()"));
        alloraAdapter.verifyData(alloraNd);
    }

    function test_cantCallVerifyDataWithInvalidDataProvider() public {
        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(_dummyNumericData(), signer0pk);  
        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataProvider()"));
        alloraAdapter.verifyData(alloraNd);
    }

    function test_viewAndNonViewFunctionsGiveSameResult() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        vm.stopPrank();

        NumericData memory nd = _dummyNumericData();
        uint256[] memory numericValues = new uint256[](2);
        numericValues[0] = 1 ether;
        numericValues[1] = 3 ether;

        nd.numericValues = numericValues;

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);

        (uint256 numericValue,) = alloraAdapter.verifyData(alloraNd);
        (uint256 numericValueView,) = alloraAdapter.verifyDataViewOnly(alloraNd);
        assertEq(numericValue, 2 ether);
        assertEq(numericValue, numericValueView);
    }

    function test_valueIsSavedWhenCallingVerifyDataWithMultipleValidSignatures() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        vm.stopPrank();

        NumericData memory nd = _dummyNumericData();
        uint256[] memory numericValues = new uint256[](2);
        numericValues[0] = 1 ether;
        numericValues[1] = 3 ether;

        nd.numericValues = numericValues;

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);
        
        uint256 recentValue0 = alloraAdapter.getTopicValue(1, '').recentValue;

        alloraAdapter.verifyData(alloraNd);

        uint256 recentValue1 = alloraAdapter.getTopicValue(1, '').recentValue;

        assertEq(recentValue0, 0);
        assertEq(recentValue1, 2 ether);
    }

    function test_valueIsSavedWhenCallingVerifyDataWithExtraDataSet() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        vm.stopPrank();

        NumericData memory nd = _dummyNumericData();
        uint256[] memory numericValues = new uint256[](2);
        numericValues[0] = 1 ether;
        numericValues[1] = 3 ether;

        nd.numericValues = numericValues;
        nd.extraData = '123';

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);
        
        uint256 recentValueEmptyExtraData0 = alloraAdapter.getTopicValue(1, '').recentValue;
        uint256 recentValue0 = alloraAdapter.getTopicValue(1, '123').recentValue;

        alloraAdapter.verifyData(alloraNd);

        uint256 recentValueEmptyExtraData1 = alloraAdapter.getTopicValue(1, '').recentValue;
        uint256 recentValue1 = alloraAdapter.getTopicValue(1, '123').recentValue;

        assertEq(recentValueEmptyExtraData0, 0);
        assertEq(recentValueEmptyExtraData1, 0);
        assertEq(recentValue0, 0);
        assertEq(recentValue1, 2 ether);
    }

    function test_dataAverageAggregationWorksCorrectly() public {
    }

    function test_dataMedianAggregationWorksCorrectly() public {

    }



    function test_dataMedianAggregationWorksCorrectly2() public {
        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        alloraAdapter.updateAggregator(medianAggregator);
        vm.stopPrank();

        NumericData memory nd = _dummyNumericData();
        uint256[] memory numericValues = new uint256[](3);
        numericValues[0] = 1 ether;
        numericValues[1] = 3 ether;
        numericValues[2] = 5 ether;

        nd.numericValues = numericValues;

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);

        (uint256 numericValue,) = alloraAdapter.verifyData(alloraNd);
        assertEq(numericValue, 3 ether);
    }

    function test_dataAggregationWorksCorrectlyAfterUpdatingAggregator() public {
        vm.startPrank(admin);
        alloraAdapter.addDataProvider(signer0);
        alloraAdapter.addDataProvider(signer1);
        alloraAdapter.addDataProvider(signer2);
        vm.stopPrank();

        NumericData memory nd = _dummyNumericData();
        uint256[] memory numericValues = new uint256[](3);
        numericValues[0] = 1 ether;
        numericValues[1] = 2 ether;
        numericValues[2] = 6 ether;

        nd.numericValues = numericValues;

        AlloraAdapterNumericData memory alloraNd = _packageAndSignNumericData(nd, signer0pk);

        (uint256 numericValue,) = alloraAdapter.verifyData(alloraNd);
        assertEq(numericValue, 3 ether);

        MedianAggregator medianAggregator = new MedianAggregator();

        vm.startPrank(admin);
        alloraAdapter.updateAggregator(medianAggregator);
        vm.stopPrank();

        (uint256 numericValue2,) = alloraAdapter.verifyData(alloraNd);
        assertEq(numericValue2, 2 ether);
    }

    // ***************************************************************
    // * ================= INTERNAL HELPERS ======================== *
    // ***************************************************************
    function _dummyNumericData() internal pure returns (NumericData memory) {
        uint256[] memory numericValues = new uint256[](1);
        numericValues[0] = 123456789012345678;

        return NumericData({
            topicId: 1,
            timestamp: 1,
            extraData: '',
            numericValues: numericValues
        });
    }


    function _signNumericData(
        NumericData memory numericData,
        uint256 signerPk
    ) internal view returns (bytes memory signature) {
        bytes32 message = alloraAdapter.getMessage(numericData);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPk, 
            ECDSA.toEthSignedMessageHash(message)
        );
        signature = abi.encodePacked(r, s, v);
    }

    function _packageNumericData(
        NumericData memory numericData,
        bytes memory signature
    ) internal pure returns (AlloraAdapterNumericData memory) {

        return AlloraAdapterNumericData({
            numericData: numericData,
            signature: signature,
            extraData: ''
        });
    }

    function _packageAndSignNumericData(
        NumericData memory numericData,
        uint256 signerPk
    ) internal view returns (AlloraAdapterNumericData memory) {
        return _packageNumericData(
            numericData, 
            _signNumericData(numericData, signerPk)
        );
    }
}
