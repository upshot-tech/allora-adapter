// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { UpshotAdapter, UpshotAdapterConstructorArgs } from "../src/UpshotAdapter.sol";
import { NumericData, Topic, TopicView, TopicConfig } from "../src/interface/IUpshotAdapter.sol";
import { EvenFeeHandler, EvenFeeHandlerConstructorArgs } from "../src/feeHandler/EvenFeeHandler.sol";
import { AverageAggregator } from "../src/aggregator/AverageAggregator.sol";
import { MedianAggregator } from "../src/aggregator/MedianAggregator.sol";
import { IAggregator } from "../src/interface/IAggregator.sol";
import { IFeeHandler } from "../src/interface/IFeeHandler.sol";

contract UpshotAdapterAdmin is Test {

    EvenFeeHandler public evenFeeHandler;
    IAggregator aggregator;
    IFeeHandler feeHandler;
    UpshotAdapter upshotAdapter;

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
        upshotAdapter = new UpshotAdapter(UpshotAdapterConstructorArgs({
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
        upshotAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();
    }

    // ***************************************************************
    // * ============= UPDATE DATA PROVIDER QUORUM ================= *
    // ***************************************************************

    function test_imposterCantUpdateDataProviderQuorum() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.updateDataProviderQuorum(1, 3);
    }

    function test_ownerCantUpdateDataProviderQuorumToZero() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidDataProviderQuorum()"));
        upshotAdapter.updateDataProviderQuorum(1, 0);
    }

    function test_ownerCanUpdateDataProviderQuorum() public {
        vm.startPrank(topicOwner);

        assertEq(upshotAdapter.getTopic(1).config.dataProviderQuorum, 1);

        upshotAdapter.updateDataProviderQuorum(1, 2);
        assertEq(upshotAdapter.getTopic(1).config.dataProviderQuorum, 2);
    }

    // ***************************************************************
    // * ============= UPDATE DATA VALIDITY SECONDS ================ *
    // ***************************************************************

    function test_imposterCantUpdateDataValiditySeconds() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.updateDataValiditySeconds(1, 10 minutes);
    }

    function test_ownerCantUpdateDataValiditySecondsToZero() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidDataValiditySeconds()"));
        upshotAdapter.updateDataValiditySeconds(1, 0);
    }

    function test_ownerCanUpdateDataValiditySeconds() public {
        vm.startPrank(topicOwner);

        assertEq(upshotAdapter.getTopic(1).config.dataValiditySeconds, 5 minutes);

        upshotAdapter.updateDataValiditySeconds(1, 10 minutes);
        assertEq(upshotAdapter.getTopic(1).config.dataValiditySeconds, 10 minutes);
    }

    // ***************************************************************
    // * ==================== ADD DATA PROVIDER ==================== *
    // ***************************************************************

    function test_imposterCantAddDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.addDataProvider(1, imposter);
    }

    function test_ownerCanAddDataProvider() public {
        vm.startPrank(topicOwner);

        assertEq(_contains(newDataProvider, upshotAdapter.getTopic(1).validDataProviders), false);

        upshotAdapter.addDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, upshotAdapter.getTopic(1).validDataProviders), true);
    }

    // ***************************************************************
    // * ================== REMOVE DATA PROVIDER =================== *
    // ***************************************************************

    function test_imposterCantRemoveDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.removeDataProvider(1, imposter);
    }

    function test_ownerCanRemoveDataProvider() public {
        vm.startPrank(topicOwner);
        upshotAdapter.addDataProvider(1, newDataProvider);

        assertEq(_contains(newDataProvider, upshotAdapter.getTopic(1).validDataProviders), true);

        upshotAdapter.removeDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, upshotAdapter.getTopic(1).validDataProviders), false);
    }

    // ***************************************************************
    // * ======================= ADD FEED ========================== *
    // ***************************************************************
    function test_ownerCantAddTopicWithEmptyTitle() public {
        vm.startPrank(admin);

        TopicView memory topicView = _getBasicTopicView();
        topicView.config.title = '';
        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidTopicTitle()"));
        upshotAdapter.addTopic(topicView);
    }

    function test_addingTopicWithValueSetIsIgnored() public {
        vm.startPrank(admin);

        uint256 topicId = upshotAdapter.addTopic(_getBasicTopicView());

        assertEq(upshotAdapter.getTopicValue(topicId, '').recentValue, 0);
        assertEq(upshotAdapter.getTopicValue(topicId, '').recentValueTime, 0);

    }

    function test_ownerCanAddTopic() public {
        vm.startPrank(admin);

        assertEq(upshotAdapter.getTopic(2).config.dataProviderQuorum, 0);

        upshotAdapter.addTopic(_getBasicTopicView());

        assertEq(upshotAdapter.getTopic(2).config.dataProviderQuorum, 1);
    }

    function test_anyoneCanAddTopic() public {
        vm.startPrank(imposter);

        assertEq(upshotAdapter.getTopic(2).config.dataProviderQuorum, 0);

        upshotAdapter.addTopic(_getBasicTopicView());

        assertEq(upshotAdapter.getTopic(2).config.dataProviderQuorum, 1);
    }

    function test_anyoneCanAddMultipleTopics() public {
        vm.startPrank(imposter);

        assertEq(upshotAdapter.getTopic(2).config.title, '');
        assertEq(upshotAdapter.getTopic(3).config.title, '');
        assertEq(upshotAdapter.getTopic(2).config.dataProviderQuorum, 0);
        assertEq(upshotAdapter.getTopic(3).config.dataProviderQuorum, 0);

        TopicView[] memory topicViews = new TopicView[](2);
        topicViews[0] = _getBasicTopicView();
        topicViews[0].config.title = 'newTopic1'; 

        topicViews[1] = _getBasicTopicView();
        topicViews[1].config.title = 'newTopic2'; 

        uint256[] memory topicIds = upshotAdapter.addTopics(topicViews);

        assertEq(upshotAdapter.getTopic(2).config.title, 'newTopic1');
        assertEq(upshotAdapter.getTopic(3).config.title, 'newTopic2');
        assertEq(upshotAdapter.getTopic(2).config.dataProviderQuorum, 1);
        assertEq(upshotAdapter.getTopic(3).config.dataProviderQuorum, 1);

        assertEq(topicIds[0], 2);
        assertEq(topicIds[1], 3);
    }

    function test_addingTopicGivesProperId() public {
        vm.startPrank(admin);
        uint256 secondTopicId = upshotAdapter.addTopic(_getBasicTopicView());
        uint256 thirdTopicId = upshotAdapter.addTopic(_getBasicTopicView());

        assertEq(secondTopicId, 2);
        assertEq(thirdTopicId, 3);
    }

    function test_addingTopicGivesAllCorrectData() public {
        vm.startPrank(admin);

        assertEq(upshotAdapter.getTopic(2).config.dataProviderQuorum, 0);

        TopicView memory secondTopic = TopicView({
            config: TopicConfig({
                title: 'secondary topic',
                owner: topicOwner2,
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

        uint256 secondTopicId = upshotAdapter.addTopic(secondTopic);
        assertEq(secondTopicId, 2);

        TopicView memory addedTopic = upshotAdapter.getTopic(secondTopicId);

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

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.turnOffTopic(1);
    }

    function test_ownerCanTurnOffTopic() public {
        vm.startPrank(upshotAdapter.getTopic(1).config.owner);

        assertEq(upshotAdapter.getTopic(1).config.ownerSwitchedOn, true);

        upshotAdapter.turnOffTopic(1);

        assertEq(upshotAdapter.getTopic(1).config.ownerSwitchedOn, false);
    }

    // ***************************************************************
    // * ================ OWNER TURN ON FEED ======================= *
    // ***************************************************************

    function test_imposterCantTurnOnTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.turnOnTopic(1);
    }

    function test_ownerCanTurnOnTopic() public {
        vm.startPrank(upshotAdapter.getTopic(1).config.owner);

        upshotAdapter.turnOffTopic(1);

        assertEq(upshotAdapter.getTopic(1).config.ownerSwitchedOn, false);

        upshotAdapter.turnOnTopic(1);

        assertEq(upshotAdapter.getTopic(1).config.ownerSwitchedOn, true);
    }

    // ***************************************************************
    // * ================ ADMIN TURN OFF FEED ====================== *
    // ***************************************************************

    function test_adminImposterCantTurnOffTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        upshotAdapter.adminTurnOffTopic(1);
    }

    function test_adminCanTurnOffTopic() public {
        vm.startPrank(admin);

        assertEq(upshotAdapter.getTopic(1).config.adminSwitchedOn, true);

        upshotAdapter.adminTurnOffTopic(1);

        assertEq(upshotAdapter.getTopic(1).config.adminSwitchedOn, false);
    }

    // ***************************************************************
    // * ================= ADMIN TURN ON FEED ====================== *
    // ***************************************************************

    function test_adminImposterCantTurnOnTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        upshotAdapter.adminTurnOnTopic(1);
    }

    function test_adminCanTurnOnTopic() public {
        vm.startPrank(admin);

        upshotAdapter.adminTurnOffTopic(1);

        assertEq(upshotAdapter.getTopic(1).config.adminSwitchedOn, false);

        upshotAdapter.adminTurnOnTopic(1);

        assertEq(upshotAdapter.getTopic(1).config.adminSwitchedOn, true);
    }

    // ***************************************************************
    // * ================= UPDATE AGGREGATOR ======================= *
    // ***************************************************************

    function test_imposterCantUpdateAggregator() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.updateAggregator(1, dummyAggregator);
    }

    function test_ownerCantUpdateAggregatorToZeroAddress() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidAggregator()"));
        upshotAdapter.updateAggregator(1, IAggregator(address(0)));
    }

    function test_ownerCanUpdateAggregator() public {
        vm.startPrank(topicOwner);

        MedianAggregator medianAggregator = new MedianAggregator();

        assertEq(address(upshotAdapter.getTopic(1).config.aggregator), address(aggregator));

        upshotAdapter.updateAggregator(1, medianAggregator);

        assertEq(address(upshotAdapter.getTopic(1).config.aggregator), address(medianAggregator));
    }

    // ***************************************************************
    // * ================= UPDATE FEE HANDLER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateFeeHandler() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.updateFeeHandler(1, dummyFeeHandler);
    }

    function test_ownerCantUpdateFeeHandlerToZeroAddress() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidFeeHandler()"));
        upshotAdapter.updateFeeHandler(1, IFeeHandler(address(0)));
    }

    function test_ownerCanUpdateFeeHandler() public {
        vm.startPrank(topicOwner);

        EvenFeeHandler newFeeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin
        }));

        assertTrue(address(feeHandler) != address(newFeeHandler));

        assertEq(address(upshotAdapter.getTopic(1).config.feeHandler), address(feeHandler));

        upshotAdapter.updateFeeHandler(1, newFeeHandler);

        assertEq(address(upshotAdapter.getTopic(1).config.feeHandler), address(newFeeHandler));
    }

    // ***************************************************************
    // * ================== UPDATE TOTAL FEE ======================= *
    // ***************************************************************

    function test_imposterCantUpdateTotalFee() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.updateTotalFee(1, 1 ether);
    }

    function test_ownerCantUpdateTotalFeeToLessThan1000() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidTotalFee()"));
        upshotAdapter.updateTotalFee(1, 999);
    }

    function test_ownerCanUpdateTotalFeeToZero() public {
        vm.startPrank(topicOwner);

        assertEq(upshotAdapter.getTopic(1).config.totalFee, 0.001 ether);

        upshotAdapter.updateTotalFee(1, 0);

        assertEq(upshotAdapter.getTopic(1).config.totalFee, 0);
    }

    function test_ownerCanUpdateTotalFee() public {
        vm.startPrank(topicOwner);

        assertEq(upshotAdapter.getTopic(1).config.totalFee, 0.001 ether);

        upshotAdapter.updateTotalFee(1, 1 ether);

        assertEq(upshotAdapter.getTopic(1).config.totalFee, 1 ether);
    }

    // ***************************************************************
    // * ================== UPDATE FEED OWNER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateTopicOwner() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2OnlyTopicOwner()"));
        upshotAdapter.updateTopicOwner(1, topicOwner2);
    }

    function test_ownerCanUpdateTopicOwner() public {
        vm.startPrank(topicOwner);

        assertEq(upshotAdapter.getTopic(1).config.owner, topicOwner);

        upshotAdapter.updateTopicOwner(1, topicOwner2);

        assertEq(upshotAdapter.getTopic(1).config.owner, topicOwner2);
    }

    // ***************************************************************
    // * ================== TURN OFF ADAPTER ======================== *
    // ***************************************************************

    function test_imposterCantTurnOffAdapter() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        upshotAdapter.adminTurnOffAdapter();
    }

    function test_ownerCanTurnOffAdapter() public {
        vm.startPrank(admin);

        assertEq(upshotAdapter.switchedOn(), true);

        upshotAdapter.adminTurnOffAdapter();

        assertEq(upshotAdapter.switchedOn(), false);
    }

    // ***************************************************************
    // * =================== TURN ON Adapter ======================== *
    // ***************************************************************

    function test_imposterCantTurnOnAdapter() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        upshotAdapter.adminTurnOnAdapter();
    }

    function test_ownerCanTurnOnAdapter() public {
        vm.startPrank(admin);
        upshotAdapter.adminTurnOffAdapter();

        assertEq(upshotAdapter.switchedOn(), false);

        upshotAdapter.adminTurnOnAdapter();

        assertEq(upshotAdapter.switchedOn(), true);
    }

    // ***************************************************************
    // * ================ UPDATE PROTOCOL FEE ====================== *
    // ***************************************************************

    function test_imposterCantUpdateProtocolFee() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        upshotAdapter.adminSetProtocolFee(1);
    }

    function test_ownerCantUpdateProtocolFeeToBeTooLarge() public {
        vm.startPrank(admin);

        assertEq(upshotAdapter.protocolFee(), 0);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2ProtocolFeeTooHigh()"));
        upshotAdapter.adminSetProtocolFee(0.5 ether + 1);
    }

    function test_ownerCanUpdateProtocolFee() public {
        vm.startPrank(admin);

        assertEq(upshotAdapter.protocolFee(), 0);

        upshotAdapter.adminSetProtocolFee(0.1 ether);

        assertEq(upshotAdapter.protocolFee(), 0.1 ether);
    }

    // ***************************************************************
    // * ============ UPDATE PROTOCOL FEE RECEIVER ================= *
    // ***************************************************************

    function test_imposterCantUpdateProtocolFeeReciever() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        upshotAdapter.adminSetProtocolFeeReceiver(protocolFeeReceiver2);
    }

    function test_ownerCantUpdateProtocolFeeReceiverToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotAdapterV2InvalidProtocolFeeReceiver()"));
        upshotAdapter.adminSetProtocolFeeReceiver(address(0));
    }

    function test_ownerCanUpdateProtocolFeeReceiver() public {
        vm.startPrank(admin);

        assertEq(upshotAdapter.protocolFeeReceiver(), protocolFeeReceiver);

        upshotAdapter.adminSetProtocolFeeReceiver(protocolFeeReceiver2);

        assertEq(upshotAdapter.protocolFeeReceiver(), protocolFeeReceiver2);
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
