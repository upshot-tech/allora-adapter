// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Oracle, OracleConstructorArgs } from "../src/Oracle.sol";
import { NumericData, Feed, FeedView } from "../src/interface/IOracle.sol";
import { EvenFeeHandler, EvenFeeHandlerConstructorArgs } from "../src/feeHandler/EvenFeeHandler.sol";
import { AverageAggregator } from "../src/aggregator/AverageAggregator.sol";
import { MedianAggregator } from "../src/aggregator/MedianAggregator.sol";
import { IAggregator } from "../src/interface/IAggregator.sol";
import { IFeeHandler } from "../src/interface/IFeeHandler.sol";

contract OraleAdmin is Test {

    EvenFeeHandler public evenFeeHandler;
    IAggregator aggregator;
    IFeeHandler feeHandler;
    Oracle oracle;

    address admin = address(100);
    address protocolFeeReceiver = address(101);

    address imposter = address(200);
    address newDataProvider = address(201);
    IAggregator dummyAggregator = IAggregator(address(202));
    IFeeHandler dummyFeeHandler = IFeeHandler(address(202));

    uint256 signer0pk = 0x1000;
    uint256 signer1pk = 0x1001;
    uint256 signer2pk = 0x1002;

    address signer0;
    address signer1;
    address signer2;

    address[] oneValidProvider;
    address[] twoValidProvider;
    address[] threeValidProviders;

    function setUp() public {
        vm.warp(1 hours);

        aggregator = new AverageAggregator();
        feeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin,
            protocolFeeReceiver: protocolFeeReceiver
        }));
        oracle = new Oracle(OracleConstructorArgs({
            admin: admin
        }));

        signer0 = vm.addr(signer0pk);
        signer1 = vm.addr(signer1pk);
        signer2 = vm.addr(signer2pk);

        oneValidProvider = new address[](1);
        oneValidProvider[0] = signer0;

        twoValidProvider = new address[](2);
        twoValidProvider[0] = signer0;
        twoValidProvider[1] = signer1;

        threeValidProviders = new address[](3);
        threeValidProviders[0] = signer0;
        threeValidProviders[1] = signer1;
        threeValidProviders[2] = signer2;

        vm.startPrank(admin);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();
    }

    // ***************************************************************
    // * ============= UPDATE DATA PROVIDER QUORUM ================= *
    // ***************************************************************

    function test_imposterCantUpdateDataProviderQuorum() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.updateDataProviderQuorum(1, 3);
    }

    function test_ownerCantUpdateDataProviderQuorumToZero() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OracleInvalidDataProviderQuorum()"));
        oracle.updateDataProviderQuorum(1, 0);
    }

    function test_ownerCanUpdateDataProviderQuorum() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(1).dataProviderQuorum, 1);

        oracle.updateDataProviderQuorum(1, 2);
        assertEq(oracle.getFeed(1).dataProviderQuorum, 2);
    }

    // ***************************************************************
    // * ============= UPDATE DATA VALIDITY SECONDS ================ *
    // ***************************************************************

    function test_imposterCantUpdateDataValiditySeconds() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.updateDataValiditySeconds(1, 10 minutes);
    }

    function test_ownerCantUpdateDataValiditySecondsToZero() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidDataValiditySeconds()"));
        oracle.updateDataValiditySeconds(1, 0);
    }

    function test_ownerCanUpdateDataValiditySeconds() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(1).dataValiditySeconds, 5 minutes);

        oracle.updateDataValiditySeconds(1, 10 minutes);
        assertEq(oracle.getFeed(1).dataValiditySeconds, 10 minutes);
    }

    // ***************************************************************
    // * ==================== ADD DATA PROVIDER ==================== *
    // ***************************************************************

    function test_imposterCantAddDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.addDataProvider(1, imposter);
    }

    function test_ownerCanAddDataProvider() public {
        vm.startPrank(admin);

        assertEq(_contains(newDataProvider, oracle.getFeed(1).validDataProviders), false);

        oracle.addDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, oracle.getFeed(1).validDataProviders), true);
    }

    // ***************************************************************
    // * ================== REMOVE DATA PROVIDER =================== *
    // ***************************************************************

    function test_imposterCantRemoveDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.removeDataProvider(1, imposter);
    }

    function test_ownerCanRemoveDataProvider() public {
        vm.startPrank(admin);
        oracle.addDataProvider(1, newDataProvider);

        assertEq(_contains(newDataProvider, oracle.getFeed(1).validDataProviders), true);

        oracle.removeDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, oracle.getFeed(1).validDataProviders), false);
    }

    // ***************************************************************
    // * ======================= ADD FEED ========================== *
    // ***************************************************************

    function test_imposterCantAddFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.addFeed(_getBasicFeedView());
    }

    function test_ownerCantAddFeedWithEmptyTitle() public {
        vm.startPrank(admin);

        FeedView memory feedView = _getBasicFeedView();
        feedView.title = '';
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeedTitle()"));
        oracle.addFeed(feedView);
    }

    function test_ownerCanAddFeed() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(2).isValid, false);

        oracle.addFeed(_getBasicFeedView());

        assertEq(oracle.getFeed(2).isValid, true);
    }

    function test_addingFeedGivesProperId() public {
        vm.startPrank(admin);
        uint256 secondFeedId = oracle.addFeed(_getBasicFeedView());
        uint256 thirdFeedId = oracle.addFeed(_getBasicFeedView());

        assertEq(secondFeedId, 2);
        assertEq(thirdFeedId, 3);
        assertEq(oracle.getFeed(2).isValid, true);
        assertEq(oracle.getFeed(3).isValid, true);
    }

    function test_addingFeedGivesAllCorrectData() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(2).isValid, false);

        FeedView memory secondFeed = FeedView({
            title: 'secondary feed',
            nonce: 1234,
            totalFee: 0.001 ether,
            dataProviderQuorum: 3,
            dataValiditySeconds: 12 minutes,
            aggregator: aggregator,
            isValid: false,
            feeHandler: feeHandler,
            validDataProviders: threeValidProviders
        });

        uint256 secondFeedId = oracle.addFeed(secondFeed);
        assertEq(secondFeedId, 2);

        FeedView memory addedFeed = oracle.getFeed(secondFeedId);
        assertEq(addedFeed.isValid, true);

        assertEq(addedFeed.title, secondFeed.title);
        assertEq(addedFeed.nonce, 1); // should always be 1 regardless
        assertEq(addedFeed.totalFee, secondFeed.totalFee);
        assertEq(addedFeed.dataProviderQuorum, secondFeed.dataProviderQuorum);
        assertEq(addedFeed.dataValiditySeconds, secondFeed.dataValiditySeconds);
        assertEq(address(addedFeed.aggregator), address(secondFeed.aggregator));
        assertTrue(address(secondFeed.aggregator) != address(0));
        assertTrue(addedFeed.isValid);
        assertEq(address(addedFeed.feeHandler), address(secondFeed.feeHandler));
        assertTrue(address(addedFeed.feeHandler) != address(0));
        assertEq(secondFeed.validDataProviders.length, 3);
        assertEq(addedFeed.validDataProviders.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertTrue(address(addedFeed.validDataProviders[i]) != address(0));
            assertEq(addedFeed.validDataProviders[i], secondFeed.validDataProviders[i]);
        }
    }

    // ***************************************************************
    // * =================== TURN OFF FEED ========================= *
    // ***************************************************************

    function test_imposterCantTurnOffFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.turnOffFeed(1);
    }

    function test_ownerCanTurnOffFeed() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(1).isValid, true);

        oracle.turnOffFeed(1);

        assertEq(oracle.getFeed(1).isValid, false);
    }

    // ***************************************************************
    // * ==================== TURN ON FEED ========================= *
    // ***************************************************************

    function test_imposterCantTurnOnFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.turnOnFeed(1);
    }

    function test_ownerCanTurnOnFeed() public {
        vm.startPrank(admin);
        oracle.turnOffFeed(1);

        assertEq(oracle.getFeed(1).isValid, false);

        oracle.turnOnFeed(1);

        assertEq(oracle.getFeed(1).isValid, true);
    }

    // ***************************************************************
    // * ================= UPDATE AGGREGATOR ======================= *
    // ***************************************************************

    function test_imposterCantUpdateAggregator() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.updateAggregator(1, dummyAggregator);
    }

    function test_ownerCantUpdateAggregatorToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidAggregator()"));
        oracle.updateAggregator(1, IAggregator(address(0)));
    }

    function test_ownerCanUpdateAggregator() public {
        vm.startPrank(admin);

        MedianAggregator medianAggregator = new MedianAggregator();

        assertEq(address(oracle.getFeed(1).aggregator), address(aggregator));

        oracle.updateAggregator(1, medianAggregator);

        assertEq(address(oracle.getFeed(1).aggregator), address(medianAggregator));
    }

    // ***************************************************************
    // * ================= UPDATE FEE HANDLER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateFeeHandler() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.updateFeeHandler(1, dummyFeeHandler);
    }

    function test_ownerCantUpdateFeeHandlerToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeeHandler()"));
        oracle.updateFeeHandler(1, IFeeHandler(address(0)));
    }

    function test_ownerCanUpdateFeeHandler() public {
        vm.startPrank(admin);

        EvenFeeHandler newFeeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin,
            protocolFeeReceiver: protocolFeeReceiver
        }));

        assertTrue(address(feeHandler) != address(newFeeHandler));

        assertEq(address(oracle.getFeed(1).feeHandler), address(feeHandler));

        oracle.updateFeeHandler(1, newFeeHandler);

        assertEq(address(oracle.getFeed(1).feeHandler), address(newFeeHandler));
    }

    // ***************************************************************
    // * ================== TURN OFF ORACLE ======================== *
    // ***************************************************************

    function test_imposterCantTurnOffOrale() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.turnOff();
    }

    function test_ownerCanTurnOffOracle() public {
        vm.startPrank(admin);

        assertEq(oracle.switchedOn(), true);

        oracle.turnOff();

        assertEq(oracle.switchedOn(), false);
    }

    // ***************************************************************
    // * =================== TURN ON ORACLE ======================== *
    // ***************************************************************

    function test_imposterCantTurnOnOracle() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.turnOn();
    }

    function test_ownerCanTurnOnOracle() public {
        vm.startPrank(admin);
        oracle.turnOff();

        assertEq(oracle.switchedOn(), false);

        oracle.turnOn();

        assertEq(oracle.switchedOn(), true);
    }

    // ***************************************************************
    // * ================== UPDATE TOTAL FEE ======================= *
    // ***************************************************************

    function test_imposterCantUpdateTotalFee() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.updateTotalFee(1, 1 ether);
    }

    function test_ownerCantUpdateTotalFeeToLessThan1000() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidTotalFee()"));
        oracle.updateTotalFee(1, 999);
    }

    function test_ownerCanUpdateTotalFeeToZero() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(1).totalFee, 0.001 ether);

        oracle.updateTotalFee(1, 0);

        assertEq(oracle.getFeed(1).totalFee, 0);
    }

    function test_ownerCanUpdateTotalFee() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(1).totalFee, 0.001 ether);

        oracle.updateTotalFee(1, 1 ether);

        assertEq(oracle.getFeed(1).totalFee, 1 ether);
    }

    function _contains(address needle, address[] memory haystack ) internal pure returns (bool) {
        for (uint i = 0; i < haystack.length; i++) {
            if (haystack[i] == needle) {
                return true;
            }
        }
        return false;
    }

    // ***************************************************************
    // * ================= INTERNAL HELPERS ======================== *
    // ***************************************************************

    function _getBasicFeedView() internal view returns (FeedView memory feedView) {
        return FeedView({
            title: 'Initial feed',
            nonce: 1,
            totalFee: 0.001 ether,
            dataProviderQuorum: 1,
            dataValiditySeconds: 5 minutes,
            aggregator: aggregator,
            isValid: true,
            feeHandler: feeHandler,
            validDataProviders: oneValidProvider
        });
    }
}
