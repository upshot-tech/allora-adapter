// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Oracle, OracleConstructorArgs } from "../src/Oracle.sol";
import { NumericData, Feed, FeedView, FeedConfig } from "../src/interface/IOracle.sol";
import { EvenFeeHandler, EvenFeeHandlerConstructorArgs } from "../src/feeHandler/EvenFeeHandler.sol";
import { AverageAggregator } from "../src/aggregator/AverageAggregator.sol";
import { MedianAggregator } from "../src/aggregator/MedianAggregator.sol";
import { IAggregator } from "../src/interface/IAggregator.sol";
import { IFeeHandler } from "../src/interface/IFeeHandler.sol";

contract OracleAdmin is Test {

    EvenFeeHandler public evenFeeHandler;
    IAggregator aggregator;
    IFeeHandler feeHandler;
    Oracle oracle;

    address admin = address(100);
    address protocolFeeReceiver = address(101);
    address protocolFeeReceiver2 = address(102);
    address feedOwner = address(103);
    address feedOwner2 = address(104);

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
            admin: admin
        }));
        oracle = new Oracle(OracleConstructorArgs({
            admin: admin,
            protocolFeeReceiver: protocolFeeReceiver
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

        vm.startPrank(feedOwner);
        oracle.addFeed(_getBasicFeedView());
        vm.stopPrank();
    }

    // ***************************************************************
    // * ============= UPDATE DATA PROVIDER QUORUM ================= *
    // ***************************************************************

    function test_imposterCantUpdateDataProviderQuorum() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.updateDataProviderQuorum(1, 3);
    }

    function test_ownerCantUpdateDataProviderQuorumToZero() public {
        vm.startPrank(feedOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidDataProviderQuorum()"));
        oracle.updateDataProviderQuorum(1, 0);
    }

    function test_ownerCanUpdateDataProviderQuorum() public {
        vm.startPrank(feedOwner);

        assertEq(oracle.getFeed(1).config.dataProviderQuorum, 1);

        oracle.updateDataProviderQuorum(1, 2);
        assertEq(oracle.getFeed(1).config.dataProviderQuorum, 2);
    }

    // ***************************************************************
    // * ============= UPDATE DATA VALIDITY SECONDS ================ *
    // ***************************************************************

    function test_imposterCantUpdateDataValiditySeconds() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.updateDataValiditySeconds(1, 10 minutes);
    }

    function test_ownerCantUpdateDataValiditySecondsToZero() public {
        vm.startPrank(feedOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidDataValiditySeconds()"));
        oracle.updateDataValiditySeconds(1, 0);
    }

    function test_ownerCanUpdateDataValiditySeconds() public {
        vm.startPrank(feedOwner);

        assertEq(oracle.getFeed(1).config.dataValiditySeconds, 5 minutes);

        oracle.updateDataValiditySeconds(1, 10 minutes);
        assertEq(oracle.getFeed(1).config.dataValiditySeconds, 10 minutes);
    }

    // ***************************************************************
    // * ==================== ADD DATA PROVIDER ==================== *
    // ***************************************************************

    function test_imposterCantAddDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.addDataProvider(1, imposter);
    }

    function test_ownerCanAddDataProvider() public {
        vm.startPrank(feedOwner);

        assertEq(_contains(newDataProvider, oracle.getFeed(1).validDataProviders), false);

        oracle.addDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, oracle.getFeed(1).validDataProviders), true);
    }

    // ***************************************************************
    // * ================== REMOVE DATA PROVIDER =================== *
    // ***************************************************************

    function test_imposterCantRemoveDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.removeDataProvider(1, imposter);
    }

    function test_ownerCanRemoveDataProvider() public {
        vm.startPrank(feedOwner);
        oracle.addDataProvider(1, newDataProvider);

        assertEq(_contains(newDataProvider, oracle.getFeed(1).validDataProviders), true);

        oracle.removeDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, oracle.getFeed(1).validDataProviders), false);
    }

    // ***************************************************************
    // * ======================= ADD FEED ========================== *
    // ***************************************************************
    function test_ownerCantAddFeedWithEmptyTitle() public {
        vm.startPrank(admin);

        FeedView memory feedView = _getBasicFeedView();
        feedView.config.title = '';
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeedTitle()"));
        oracle.addFeed(feedView);
    }

    function test_ownerCanAddFeed() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(2).config.dataProviderQuorum, 0);

        oracle.addFeed(_getBasicFeedView());

        assertEq(oracle.getFeed(2).config.dataProviderQuorum, 1);
    }

    function test_addingFeedGivesProperId() public {
        vm.startPrank(admin);
        uint256 secondFeedId = oracle.addFeed(_getBasicFeedView());
        uint256 thirdFeedId = oracle.addFeed(_getBasicFeedView());

        assertEq(secondFeedId, 2);
        assertEq(thirdFeedId, 3);
    }

    function test_addingFeedGivesAllCorrectData() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(2).config.dataProviderQuorum, 0);

        FeedView memory secondFeed = FeedView({
            config: FeedConfig({
                title: 'secondary feed',
                owner: feedOwner2,
                totalFee: 0.001 ether,
                aggregator: aggregator,
                ownerSwitchedOn: false,
                adminSwitchedOn: false,
                feeHandler: feeHandler,
                dataProviderQuorum: 3,
                dataValiditySeconds: 12 minutes
            }),
            validDataProviders: threeValidProviders
        });

        uint256 secondFeedId = oracle.addFeed(secondFeed);
        assertEq(secondFeedId, 2);

        FeedView memory addedFeed = oracle.getFeed(secondFeedId);

        assertEq(addedFeed.config.title, secondFeed.config.title);
        assertEq(addedFeed.config.owner, secondFeed.config.owner);
        assertEq(addedFeed.config.totalFee, secondFeed.config.totalFee);
        assertEq(addedFeed.config.dataProviderQuorum, secondFeed.config.dataProviderQuorum);
        assertEq(addedFeed.config.dataValiditySeconds, secondFeed.config.dataValiditySeconds);
        assertEq(address(addedFeed.config.aggregator), address(secondFeed.config.aggregator));
        assertTrue(address(secondFeed.config.aggregator) != address(0));
        assertEq(addedFeed.config.ownerSwitchedOn, secondFeed.config.ownerSwitchedOn);
        assertEq(addedFeed.config.adminSwitchedOn, secondFeed.config.adminSwitchedOn);
        assertEq(address(addedFeed.config.feeHandler), address(secondFeed.config.feeHandler));
        assertTrue(address(addedFeed.config.feeHandler) != address(0));
        assertEq(secondFeed.validDataProviders.length, 3);
        assertEq(addedFeed.validDataProviders.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertTrue(address(addedFeed.validDataProviders[i]) != address(0));
            assertEq(addedFeed.validDataProviders[i], secondFeed.validDataProviders[i]);
        }
    }

    // ***************************************************************
    // * ================ OWNER TURN OFF FEED ====================== *
    // ***************************************************************

    function test_imposterCantTurnOffFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.turnOffFeed(1);
    }

    function test_ownerCanTurnOffFeed() public {
        vm.startPrank(oracle.getFeed(1).config.owner);

        assertEq(oracle.getFeed(1).config.ownerSwitchedOn, true);

        oracle.turnOffFeed(1);

        assertEq(oracle.getFeed(1).config.ownerSwitchedOn, false);
    }

    // ***************************************************************
    // * ================ OWNER TURN ON FEED ======================= *
    // ***************************************************************

    function test_imposterCantTurnOnFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.turnOnFeed(1);
    }

    function test_ownerCanTurnOnFeed() public {
        vm.startPrank(oracle.getFeed(1).config.owner);

        oracle.turnOffFeed(1);

        assertEq(oracle.getFeed(1).config.ownerSwitchedOn, false);

        oracle.turnOnFeed(1);

        assertEq(oracle.getFeed(1).config.ownerSwitchedOn, true);
    }

    // ***************************************************************
    // * ================ ADMIN TURN OFF FEED ====================== *
    // ***************************************************************

    function test_adminImposterCantTurnOffFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.adminTurnOffFeed(1);
    }

    function test_adminCanTurnOffFeed() public {
        vm.startPrank(admin);

        assertEq(oracle.getFeed(1).config.adminSwitchedOn, true);

        oracle.adminTurnOffFeed(1);

        assertEq(oracle.getFeed(1).config.adminSwitchedOn, false);
    }

    // ***************************************************************
    // * ================= ADMIN TURN ON FEED ====================== *
    // ***************************************************************

    function test_adminImposterCantTurnOnFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.adminTurnOnFeed(1);
    }

    function test_adminCanTurnOnFeed() public {
        vm.startPrank(admin);

        oracle.adminTurnOffFeed(1);

        assertEq(oracle.getFeed(1).config.adminSwitchedOn, false);

        oracle.adminTurnOnFeed(1);

        assertEq(oracle.getFeed(1).config.adminSwitchedOn, true);
    }

    // ***************************************************************
    // * ================= UPDATE AGGREGATOR ======================= *
    // ***************************************************************

    function test_imposterCantUpdateAggregator() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.updateAggregator(1, dummyAggregator);
    }

    function test_ownerCantUpdateAggregatorToZeroAddress() public {
        vm.startPrank(feedOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidAggregator()"));
        oracle.updateAggregator(1, IAggregator(address(0)));
    }

    function test_ownerCanUpdateAggregator() public {
        vm.startPrank(feedOwner);

        MedianAggregator medianAggregator = new MedianAggregator();

        assertEq(address(oracle.getFeed(1).config.aggregator), address(aggregator));

        oracle.updateAggregator(1, medianAggregator);

        assertEq(address(oracle.getFeed(1).config.aggregator), address(medianAggregator));
    }

    // ***************************************************************
    // * ================= UPDATE FEE HANDLER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateFeeHandler() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.updateFeeHandler(1, dummyFeeHandler);
    }

    function test_ownerCantUpdateFeeHandlerToZeroAddress() public {
        vm.startPrank(feedOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeeHandler()"));
        oracle.updateFeeHandler(1, IFeeHandler(address(0)));
    }

    function test_ownerCanUpdateFeeHandler() public {
        vm.startPrank(feedOwner);

        EvenFeeHandler newFeeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin
        }));

        assertTrue(address(feeHandler) != address(newFeeHandler));

        assertEq(address(oracle.getFeed(1).config.feeHandler), address(feeHandler));

        oracle.updateFeeHandler(1, newFeeHandler);

        assertEq(address(oracle.getFeed(1).config.feeHandler), address(newFeeHandler));
    }

    // ***************************************************************
    // * ================== UPDATE TOTAL FEE ======================= *
    // ***************************************************************

    function test_imposterCantUpdateTotalFee() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.updateTotalFee(1, 1 ether);
    }

    function test_ownerCantUpdateTotalFeeToLessThan1000() public {
        vm.startPrank(feedOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidTotalFee()"));
        oracle.updateTotalFee(1, 999);
    }

    function test_ownerCanUpdateTotalFeeToZero() public {
        vm.startPrank(feedOwner);

        assertEq(oracle.getFeed(1).config.totalFee, 0.001 ether);

        oracle.updateTotalFee(1, 0);

        assertEq(oracle.getFeed(1).config.totalFee, 0);
    }

    function test_ownerCanUpdateTotalFee() public {
        vm.startPrank(feedOwner);

        assertEq(oracle.getFeed(1).config.totalFee, 0.001 ether);

        oracle.updateTotalFee(1, 1 ether);

        assertEq(oracle.getFeed(1).config.totalFee, 1 ether);
    }

    // ***************************************************************
    // * ================== UPDATE FEED OWNER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateFeedOwner() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyFeedOwner()"));
        oracle.updateFeedOwner(1, feedOwner2);
    }

    function test_ownerCanUpdateFeedOwner() public {
        vm.startPrank(feedOwner);

        assertEq(oracle.getFeed(1).config.owner, feedOwner);

        oracle.updateFeedOwner(1, feedOwner2);

        assertEq(oracle.getFeed(1).config.owner, feedOwner2);
    }

    // ***************************************************************
    // * ================== TURN OFF ORACLE ======================== *
    // ***************************************************************

    function test_imposterCantTurnOffOracle() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.adminTurnOffOracle();
    }

    function test_ownerCanTurnOffOracle() public {
        vm.startPrank(admin);

        assertEq(oracle.switchedOn(), true);

        oracle.adminTurnOffOracle();

        assertEq(oracle.switchedOn(), false);
    }

    // ***************************************************************
    // * =================== TURN ON ORACLE ======================== *
    // ***************************************************************

    function test_imposterCantTurnOnOracle() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.adminTurnOnOracle();
    }

    function test_ownerCanTurnOnOracle() public {
        vm.startPrank(admin);
        oracle.adminTurnOffOracle();

        assertEq(oracle.switchedOn(), false);

        oracle.adminTurnOnOracle();

        assertEq(oracle.switchedOn(), true);
    }

    // ***************************************************************
    // * ================ UPDATE PROTOCOL FEE ====================== *
    // ***************************************************************

    function test_imposterCantUpdateProtocolFee() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.adminSetProtocolFee(1);
    }

    function test_ownerCantUpdateProtocolFeeToBeTooLarge() public {
        vm.startPrank(admin);

        assertEq(oracle.protocolFee(), 0);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2ProtocolFeeTooHigh()"));
        oracle.adminSetProtocolFee(0.5 ether + 1);
    }

    function test_ownerCanUpdateProtocolFee() public {
        vm.startPrank(admin);

        assertEq(oracle.protocolFee(), 0);

        oracle.adminSetProtocolFee(0.1 ether);

        assertEq(oracle.protocolFee(), 0.1 ether);
    }

    // ***************************************************************
    // * ============ UPDATE PROTOCOL FEE RECEIVER ================= *
    // ***************************************************************

    function test_imposterCantUpdateProtocolFeeReciever() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.adminSetProtocolFeeReceiver(protocolFeeReceiver2);
    }

    function test_ownerCantUpdateProtocolFeeReceiverToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidProtocolFeeReceiver()"));
        oracle.adminSetProtocolFeeReceiver(address(0));
    }

    function test_ownerCanUpdateProtocolFeeReceiver() public {
        vm.startPrank(admin);

        assertEq(oracle.protocolFeeReceiver(), protocolFeeReceiver);

        oracle.adminSetProtocolFeeReceiver(protocolFeeReceiver2);

        assertEq(oracle.protocolFeeReceiver(), protocolFeeReceiver2);
    }

    // ***************************************************************
    // * ================= INTERNAL HELPERS ======================== *
    // ***************************************************************

    function _contains(address needle, address[] memory haystack) internal pure returns (bool) {
        for (uint i = 0; i < haystack.length; i++) {
            if (haystack[i] == needle) {
                return true;
            }
        }
        return false;
    }

    function _getBasicFeedView() internal view returns (FeedView memory feedView) {
        return FeedView({
            config: FeedConfig({
                title: 'Initial feed',
                owner: feedOwner,
                totalFee: 0.001 ether,
                aggregator: aggregator,
                ownerSwitchedOn: true,
                adminSwitchedOn: true,
                feeHandler: feeHandler,
                dataProviderQuorum: 1,
                dataValiditySeconds: 5 minutes
            }),
            validDataProviders: oneValidProvider
        });
    }
}
