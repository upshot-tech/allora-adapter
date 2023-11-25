// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Oracle, OracleConstructorArgs } from "../src/Oracle.sol";
import { NumericData, Topic, TopicView, TopicConfig } from "../src/interface/IOracle.sol";
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
    address topicOwner = address(103);
    address topicOwner2 = address(104);

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

        vm.startPrank(topicOwner);
        oracle.addTopic(_getBasicTopicView());
        vm.stopPrank();
    }

    // ***************************************************************
    // * ============= UPDATE DATA PROVIDER QUORUM ================= *
    // ***************************************************************

    function test_imposterCantUpdateDataProviderQuorum() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.updateDataProviderQuorum(1, 3);
    }

    function test_ownerCantUpdateDataProviderQuorumToZero() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidDataProviderQuorum()"));
        oracle.updateDataProviderQuorum(1, 0);
    }

    function test_ownerCanUpdateDataProviderQuorum() public {
        vm.startPrank(topicOwner);

        assertEq(oracle.getTopic(1).config.dataProviderQuorum, 1);

        oracle.updateDataProviderQuorum(1, 2);
        assertEq(oracle.getTopic(1).config.dataProviderQuorum, 2);
    }

    // ***************************************************************
    // * ============= UPDATE DATA VALIDITY SECONDS ================ *
    // ***************************************************************

    function test_imposterCantUpdateDataValiditySeconds() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.updateDataValiditySeconds(1, 10 minutes);
    }

    function test_ownerCantUpdateDataValiditySecondsToZero() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidDataValiditySeconds()"));
        oracle.updateDataValiditySeconds(1, 0);
    }

    function test_ownerCanUpdateDataValiditySeconds() public {
        vm.startPrank(topicOwner);

        assertEq(oracle.getTopic(1).config.dataValiditySeconds, 5 minutes);

        oracle.updateDataValiditySeconds(1, 10 minutes);
        assertEq(oracle.getTopic(1).config.dataValiditySeconds, 10 minutes);
    }

    // ***************************************************************
    // * ==================== ADD DATA PROVIDER ==================== *
    // ***************************************************************

    function test_imposterCantAddDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.addDataProvider(1, imposter);
    }

    function test_ownerCanAddDataProvider() public {
        vm.startPrank(topicOwner);

        assertEq(_contains(newDataProvider, oracle.getTopic(1).validDataProviders), false);

        oracle.addDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, oracle.getTopic(1).validDataProviders), true);
    }

    // ***************************************************************
    // * ================== REMOVE DATA PROVIDER =================== *
    // ***************************************************************

    function test_imposterCantRemoveDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.removeDataProvider(1, imposter);
    }

    function test_ownerCanRemoveDataProvider() public {
        vm.startPrank(topicOwner);
        oracle.addDataProvider(1, newDataProvider);

        assertEq(_contains(newDataProvider, oracle.getTopic(1).validDataProviders), true);

        oracle.removeDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, oracle.getTopic(1).validDataProviders), false);
    }

    // ***************************************************************
    // * ======================= ADD FEED ========================== *
    // ***************************************************************
    function test_ownerCantAddTopicWithEmptyTitle() public {
        vm.startPrank(admin);

        TopicView memory topicView = _getBasicTopicView();
        topicView.config.title = '';
        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidTopicTitle()"));
        oracle.addTopic(topicView);
    }

    function test_addingTopicWithValueSetIsIgnored() public {
        vm.startPrank(admin);

        TopicView memory topicView = _getBasicTopicView();
        topicView.config.recentValue = 1;
        topicView.config.recentValueTime = 2;

        uint256 topicId = oracle.addTopic(topicView);

        assertEq(oracle.getTopic(topicId).config.recentValue, 0);
        assertEq(oracle.getTopic(topicId).config.recentValueTime, 0);

    }

    function test_ownerCanAddTopic() public {
        vm.startPrank(admin);

        assertEq(oracle.getTopic(2).config.dataProviderQuorum, 0);

        oracle.addTopic(_getBasicTopicView());

        assertEq(oracle.getTopic(2).config.dataProviderQuorum, 1);
    }

    function test_addingTopicGivesProperId() public {
        vm.startPrank(admin);
        uint256 secondTopicId = oracle.addTopic(_getBasicTopicView());
        uint256 thirdTopicId = oracle.addTopic(_getBasicTopicView());

        assertEq(secondTopicId, 2);
        assertEq(thirdTopicId, 3);
    }

    function test_addingTopicGivesAllCorrectData() public {
        vm.startPrank(admin);

        assertEq(oracle.getTopic(2).config.dataProviderQuorum, 0);

        TopicView memory secondTopic = TopicView({
            config: TopicConfig({
                title: 'secondary topic',
                owner: topicOwner2,
                totalFee: 0.001 ether,
                recentValueTime: 0,
                recentValue: 0,
                aggregator: aggregator,
                ownerSwitchedOn: false,
                adminSwitchedOn: false,
                feeHandler: feeHandler,
                dataProviderQuorum: 3,
                dataValiditySeconds: 12 minutes
            }),
            validDataProviders: threeValidProviders
        });

        uint256 secondTopicId = oracle.addTopic(secondTopic);
        assertEq(secondTopicId, 2);

        TopicView memory addedTopic = oracle.getTopic(secondTopicId);

        assertEq(addedTopic.config.title, secondTopic.config.title);
        assertEq(addedTopic.config.owner, secondTopic.config.owner);
        assertEq(addedTopic.config.totalFee, secondTopic.config.totalFee);
        assertEq(addedTopic.config.dataProviderQuorum, secondTopic.config.dataProviderQuorum);
        assertEq(addedTopic.config.dataValiditySeconds, secondTopic.config.dataValiditySeconds);
        assertEq(address(addedTopic.config.aggregator), address(secondTopic.config.aggregator));
        assertTrue(address(secondTopic.config.aggregator) != address(0));
        assertEq(addedTopic.config.ownerSwitchedOn, secondTopic.config.ownerSwitchedOn);
        assertEq(addedTopic.config.adminSwitchedOn, secondTopic.config.adminSwitchedOn);
        assertEq(address(addedTopic.config.feeHandler), address(secondTopic.config.feeHandler));
        assertTrue(address(addedTopic.config.feeHandler) != address(0));
        assertEq(secondTopic.validDataProviders.length, 3);
        assertEq(addedTopic.validDataProviders.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertTrue(address(addedTopic.validDataProviders[i]) != address(0));
            assertEq(addedTopic.validDataProviders[i], secondTopic.validDataProviders[i]);
        }
    }

    // ***************************************************************
    // * ================ OWNER TURN OFF FEED ====================== *
    // ***************************************************************

    function test_imposterCantTurnOffTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.turnOffTopic(1);
    }

    function test_ownerCanTurnOffTopic() public {
        vm.startPrank(oracle.getTopic(1).config.owner);

        assertEq(oracle.getTopic(1).config.ownerSwitchedOn, true);

        oracle.turnOffTopic(1);

        assertEq(oracle.getTopic(1).config.ownerSwitchedOn, false);
    }

    // ***************************************************************
    // * ================ OWNER TURN ON FEED ======================= *
    // ***************************************************************

    function test_imposterCantTurnOnTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.turnOnTopic(1);
    }

    function test_ownerCanTurnOnTopic() public {
        vm.startPrank(oracle.getTopic(1).config.owner);

        oracle.turnOffTopic(1);

        assertEq(oracle.getTopic(1).config.ownerSwitchedOn, false);

        oracle.turnOnTopic(1);

        assertEq(oracle.getTopic(1).config.ownerSwitchedOn, true);
    }

    // ***************************************************************
    // * ================ ADMIN TURN OFF FEED ====================== *
    // ***************************************************************

    function test_adminImposterCantTurnOffTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.adminTurnOffTopic(1);
    }

    function test_adminCanTurnOffTopic() public {
        vm.startPrank(admin);

        assertEq(oracle.getTopic(1).config.adminSwitchedOn, true);

        oracle.adminTurnOffTopic(1);

        assertEq(oracle.getTopic(1).config.adminSwitchedOn, false);
    }

    // ***************************************************************
    // * ================= ADMIN TURN ON FEED ====================== *
    // ***************************************************************

    function test_adminImposterCantTurnOnTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        oracle.adminTurnOnTopic(1);
    }

    function test_adminCanTurnOnTopic() public {
        vm.startPrank(admin);

        oracle.adminTurnOffTopic(1);

        assertEq(oracle.getTopic(1).config.adminSwitchedOn, false);

        oracle.adminTurnOnTopic(1);

        assertEq(oracle.getTopic(1).config.adminSwitchedOn, true);
    }

    // ***************************************************************
    // * ================= UPDATE AGGREGATOR ======================= *
    // ***************************************************************

    function test_imposterCantUpdateAggregator() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.updateAggregator(1, dummyAggregator);
    }

    function test_ownerCantUpdateAggregatorToZeroAddress() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidAggregator()"));
        oracle.updateAggregator(1, IAggregator(address(0)));
    }

    function test_ownerCanUpdateAggregator() public {
        vm.startPrank(topicOwner);

        MedianAggregator medianAggregator = new MedianAggregator();

        assertEq(address(oracle.getTopic(1).config.aggregator), address(aggregator));

        oracle.updateAggregator(1, medianAggregator);

        assertEq(address(oracle.getTopic(1).config.aggregator), address(medianAggregator));
    }

    // ***************************************************************
    // * ================= UPDATE FEE HANDLER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateFeeHandler() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.updateFeeHandler(1, dummyFeeHandler);
    }

    function test_ownerCantUpdateFeeHandlerToZeroAddress() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeeHandler()"));
        oracle.updateFeeHandler(1, IFeeHandler(address(0)));
    }

    function test_ownerCanUpdateFeeHandler() public {
        vm.startPrank(topicOwner);

        EvenFeeHandler newFeeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin
        }));

        assertTrue(address(feeHandler) != address(newFeeHandler));

        assertEq(address(oracle.getTopic(1).config.feeHandler), address(feeHandler));

        oracle.updateFeeHandler(1, newFeeHandler);

        assertEq(address(oracle.getTopic(1).config.feeHandler), address(newFeeHandler));
    }

    // ***************************************************************
    // * ================== UPDATE TOTAL FEE ======================= *
    // ***************************************************************

    function test_imposterCantUpdateTotalFee() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.updateTotalFee(1, 1 ether);
    }

    function test_ownerCantUpdateTotalFeeToLessThan1000() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidTotalFee()"));
        oracle.updateTotalFee(1, 999);
    }

    function test_ownerCanUpdateTotalFeeToZero() public {
        vm.startPrank(topicOwner);

        assertEq(oracle.getTopic(1).config.totalFee, 0.001 ether);

        oracle.updateTotalFee(1, 0);

        assertEq(oracle.getTopic(1).config.totalFee, 0);
    }

    function test_ownerCanUpdateTotalFee() public {
        vm.startPrank(topicOwner);

        assertEq(oracle.getTopic(1).config.totalFee, 0.001 ether);

        oracle.updateTotalFee(1, 1 ether);

        assertEq(oracle.getTopic(1).config.totalFee, 1 ether);
    }

    // ***************************************************************
    // * ================== UPDATE FEED OWNER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateTopicOwner() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2OnlyTopicOwner()"));
        oracle.updateTopicOwner(1, topicOwner2);
    }

    function test_ownerCanUpdateTopicOwner() public {
        vm.startPrank(topicOwner);

        assertEq(oracle.getTopic(1).config.owner, topicOwner);

        oracle.updateTopicOwner(1, topicOwner2);

        assertEq(oracle.getTopic(1).config.owner, topicOwner2);
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

    function _getBasicTopicView() internal view returns (TopicView memory topicView) {
        return TopicView({
            config: TopicConfig({
                title: 'Initial topic',
                owner: topicOwner,
                totalFee: 0.001 ether,
                recentValueTime: 0,
                recentValue: 0,
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
