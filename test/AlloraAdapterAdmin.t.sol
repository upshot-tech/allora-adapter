// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { AlloraAdapter, AlloraAdapterConstructorArgs } from "../src/AlloraAdapter.sol";
import { NumericData, Topic, TopicView, TopicConfig } from "../src/interface/IAlloraAdapter.sol";
import { EvenFeeHandler, EvenFeeHandlerConstructorArgs } from "../src/feeHandler/EvenFeeHandler.sol";
import { AverageAggregator } from "../src/aggregator/AverageAggregator.sol";
import { MedianAggregator } from "../src/aggregator/MedianAggregator.sol";
import { IAggregator } from "../src/interface/IAggregator.sol";
import { IFeeHandler } from "../src/interface/IFeeHandler.sol";

contract AlloraAdapterAdmin is Test {

    EvenFeeHandler public evenFeeHandler;
    IAggregator aggregator;
    AlloraAdapter alloraAdapter;

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
        alloraAdapter = new AlloraAdapter(AlloraAdapterConstructorArgs({ admin: admin }));

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
        alloraAdapter.addTopic(_getBasicTopicView());
        vm.stopPrank();
    }

    // ***************************************************************
    // * ============= UPDATE DATA PROVIDER QUORUM ================= *
    // ***************************************************************

    function test_imposterCantUpdateDataProviderQuorum() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2OnlyTopicOwner()"));
        alloraAdapter.updateDataProviderQuorum(1, 3);
    }

    function test_ownerCantUpdateDataProviderQuorumToZero() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataProviderQuorum()"));
        alloraAdapter.updateDataProviderQuorum(1, 0);
    }

    function test_ownerCanUpdateDataProviderQuorum() public {
        vm.startPrank(topicOwner);

        assertEq(alloraAdapter.getTopic(1).config.dataProviderQuorum, 1);

        alloraAdapter.updateDataProviderQuorum(1, 2);
        assertEq(alloraAdapter.getTopic(1).config.dataProviderQuorum, 2);
    }

    // ***************************************************************
    // * ============= UPDATE DATA VALIDITY SECONDS ================ *
    // ***************************************************************

    function test_imposterCantUpdateDataValiditySeconds() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2OnlyTopicOwner()"));
        alloraAdapter.updateDataValiditySeconds(1, 10 minutes);
    }

    function test_ownerCantUpdateDataValiditySecondsToZero() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataValiditySeconds()"));
        alloraAdapter.updateDataValiditySeconds(1, 0);
    }

    function test_ownerCanUpdateDataValiditySeconds() public {
        vm.startPrank(topicOwner);

        assertEq(alloraAdapter.getTopic(1).config.dataValiditySeconds, 5 minutes);

        alloraAdapter.updateDataValiditySeconds(1, 10 minutes);
        assertEq(alloraAdapter.getTopic(1).config.dataValiditySeconds, 10 minutes);
    }

    // ***************************************************************
    // * ==================== ADD DATA PROVIDER ==================== *
    // ***************************************************************

    function test_imposterCantAddDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2OnlyTopicOwner()"));
        alloraAdapter.addDataProvider(1, imposter);
    }

    function test_ownerCanAddDataProvider() public {
        vm.startPrank(topicOwner);

        assertEq(_contains(newDataProvider, alloraAdapter.getTopic(1).validDataProviders), false);

        alloraAdapter.addDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, alloraAdapter.getTopic(1).validDataProviders), true);
    }

    // ***************************************************************
    // * ================== REMOVE DATA PROVIDER =================== *
    // ***************************************************************

    function test_imposterCantRemoveDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2OnlyTopicOwner()"));
        alloraAdapter.removeDataProvider(1, imposter);
    }

    function test_ownerCanRemoveDataProvider() public {
        vm.startPrank(topicOwner);
        alloraAdapter.addDataProvider(1, newDataProvider);

        assertEq(_contains(newDataProvider, alloraAdapter.getTopic(1).validDataProviders), true);

        alloraAdapter.removeDataProvider(1, newDataProvider);
        assertEq(_contains(newDataProvider, alloraAdapter.getTopic(1).validDataProviders), false);
    }

    // ***************************************************************
    // * ======================= ADD FEED ========================== *
    // ***************************************************************
    function test_ownerCantAddTopicWithEmptyTitle() public {
        vm.startPrank(admin);

        TopicView memory topicView = _getBasicTopicView();
        topicView.config.title = '';
        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidTopicTitle()"));
        alloraAdapter.addTopic(topicView);
    }

    function test_addingTopicWithValueSetIsIgnored() public {
        vm.startPrank(admin);

        uint256 topicId = alloraAdapter.addTopic(_getBasicTopicView());

        assertEq(alloraAdapter.getTopicValue(topicId, '').recentValue, 0);
        assertEq(alloraAdapter.getTopicValue(topicId, '').recentValueTime, 0);

    }

    function test_ownerCanAddTopic() public {
        vm.startPrank(admin);

        assertEq(alloraAdapter.getTopic(2).config.dataProviderQuorum, 0);

        alloraAdapter.addTopic(_getBasicTopicView());

        assertEq(alloraAdapter.getTopic(2).config.dataProviderQuorum, 1);
    }

    function test_anyoneCanAddTopic() public {
        vm.startPrank(imposter);

        assertEq(alloraAdapter.getTopic(2).config.dataProviderQuorum, 0);

        alloraAdapter.addTopic(_getBasicTopicView());

        assertEq(alloraAdapter.getTopic(2).config.dataProviderQuorum, 1);
    }

    function test_anyoneCanAddMultipleTopics() public {
        vm.startPrank(imposter);

        assertEq(alloraAdapter.getTopic(2).config.title, '');
        assertEq(alloraAdapter.getTopic(3).config.title, '');
        assertEq(alloraAdapter.getTopic(2).config.dataProviderQuorum, 0);
        assertEq(alloraAdapter.getTopic(3).config.dataProviderQuorum, 0);

        TopicView[] memory topicViews = new TopicView[](2);
        topicViews[0] = _getBasicTopicView();
        topicViews[0].config.title = 'newTopic1'; 

        topicViews[1] = _getBasicTopicView();
        topicViews[1].config.title = 'newTopic2'; 

        uint256[] memory topicIds = alloraAdapter.addTopics(topicViews);

        assertEq(alloraAdapter.getTopic(2).config.title, 'newTopic1');
        assertEq(alloraAdapter.getTopic(3).config.title, 'newTopic2');
        assertEq(alloraAdapter.getTopic(2).config.dataProviderQuorum, 1);
        assertEq(alloraAdapter.getTopic(3).config.dataProviderQuorum, 1);

        assertEq(topicIds[0], 2);
        assertEq(topicIds[1], 3);
    }

    function test_addingTopicGivesProperId() public {
        vm.startPrank(admin);
        uint256 secondTopicId = alloraAdapter.addTopic(_getBasicTopicView());
        uint256 thirdTopicId = alloraAdapter.addTopic(_getBasicTopicView());

        assertEq(secondTopicId, 2);
        assertEq(thirdTopicId, 3);
    }

    function test_addingTopicGivesAllCorrectData() public {
        vm.startPrank(admin);

        assertEq(alloraAdapter.getTopic(2).config.dataProviderQuorum, 0);

        TopicView memory secondTopic = TopicView({
            config: TopicConfig({
                title: 'secondary topic',
                owner: topicOwner2,
                aggregator: aggregator,
                ownerSwitchedOn: false,
                adminSwitchedOn: false,
                dataProviderQuorum: 3,
                dataValiditySeconds: 12 minutes
            }),
            validDataProviders: threeValidProviders
        });

        uint256 secondTopicId = alloraAdapter.addTopic(secondTopic);
        assertEq(secondTopicId, 2);

        TopicView memory addedTopic = alloraAdapter.getTopic(secondTopicId);

        assertEq(addedTopic.config.title, secondTopic.config.title);
        assertEq(addedTopic.config.owner, secondTopic.config.owner);
        assertEq(addedTopic.config.dataProviderQuorum, secondTopic.config.dataProviderQuorum);
        assertEq(addedTopic.config.dataValiditySeconds, secondTopic.config.dataValiditySeconds);
        assertEq(address(addedTopic.config.aggregator), address(secondTopic.config.aggregator));
        assertTrue(address(secondTopic.config.aggregator) != address(0));
        assertEq(addedTopic.config.ownerSwitchedOn, secondTopic.config.ownerSwitchedOn);
        assertEq(addedTopic.config.adminSwitchedOn, secondTopic.config.adminSwitchedOn);
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

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2OnlyTopicOwner()"));
        alloraAdapter.turnOffTopic(1);
    }

    function test_ownerCanTurnOffTopic() public {
        vm.startPrank(alloraAdapter.getTopic(1).config.owner);

        assertEq(alloraAdapter.getTopic(1).config.ownerSwitchedOn, true);

        alloraAdapter.turnOffTopic(1);

        assertEq(alloraAdapter.getTopic(1).config.ownerSwitchedOn, false);
    }

    // ***************************************************************
    // * ================ OWNER TURN ON FEED ======================= *
    // ***************************************************************

    function test_imposterCantTurnOnTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2OnlyTopicOwner()"));
        alloraAdapter.turnOnTopic(1);
    }

    function test_ownerCanTurnOnTopic() public {
        vm.startPrank(alloraAdapter.getTopic(1).config.owner);

        alloraAdapter.turnOffTopic(1);

        assertEq(alloraAdapter.getTopic(1).config.ownerSwitchedOn, false);

        alloraAdapter.turnOnTopic(1);

        assertEq(alloraAdapter.getTopic(1).config.ownerSwitchedOn, true);
    }

    // ***************************************************************
    // * ================ ADMIN TURN OFF FEED ====================== *
    // ***************************************************************

    function test_adminImposterCantTurnOffTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        alloraAdapter.adminTurnOffTopic(1);
    }

    function test_adminCanTurnOffTopic() public {
        vm.startPrank(admin);

        assertEq(alloraAdapter.getTopic(1).config.adminSwitchedOn, true);

        alloraAdapter.adminTurnOffTopic(1);

        assertEq(alloraAdapter.getTopic(1).config.adminSwitchedOn, false);
    }

    // ***************************************************************
    // * ================= ADMIN TURN ON FEED ====================== *
    // ***************************************************************

    function test_adminImposterCantTurnOnTopic() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        alloraAdapter.adminTurnOnTopic(1);
    }

    function test_adminCanTurnOnTopic() public {
        vm.startPrank(admin);

        alloraAdapter.adminTurnOffTopic(1);

        assertEq(alloraAdapter.getTopic(1).config.adminSwitchedOn, false);

        alloraAdapter.adminTurnOnTopic(1);

        assertEq(alloraAdapter.getTopic(1).config.adminSwitchedOn, true);
    }

    // ***************************************************************
    // * ================= UPDATE AGGREGATOR ======================= *
    // ***************************************************************

    function test_imposterCantUpdateAggregator() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2OnlyTopicOwner()"));
        alloraAdapter.updateAggregator(1, dummyAggregator);
    }

    function test_ownerCantUpdateAggregatorToZeroAddress() public {
        vm.startPrank(topicOwner);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidAggregator()"));
        alloraAdapter.updateAggregator(1, IAggregator(address(0)));
    }

    function test_ownerCanUpdateAggregator() public {
        vm.startPrank(topicOwner);

        MedianAggregator medianAggregator = new MedianAggregator();

        assertEq(address(alloraAdapter.getTopic(1).config.aggregator), address(aggregator));

        alloraAdapter.updateAggregator(1, medianAggregator);

        assertEq(address(alloraAdapter.getTopic(1).config.aggregator), address(medianAggregator));
    }

    // ***************************************************************
    // * ================== UPDATE FEED OWNER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateTopicOwner() public {
        vm.startPrank(imposter);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2OnlyTopicOwner()"));
        alloraAdapter.updateTopicOwner(1, topicOwner2);
    }

    function test_ownerCanUpdateTopicOwner() public {
        vm.startPrank(topicOwner);

        assertEq(alloraAdapter.getTopic(1).config.owner, topicOwner);

        alloraAdapter.updateTopicOwner(1, topicOwner2);

        assertEq(alloraAdapter.getTopic(1).config.owner, topicOwner2);
    }

    // ***************************************************************
    // * ================== TURN OFF ADAPTER ======================== *
    // ***************************************************************

    function test_imposterCantTurnOffAdapter() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        alloraAdapter.adminTurnOffAdapter();
    }

    function test_ownerCanTurnOffAdapter() public {
        vm.startPrank(admin);

        assertEq(alloraAdapter.switchedOn(), true);

        alloraAdapter.adminTurnOffAdapter();

        assertEq(alloraAdapter.switchedOn(), false);
    }

    // ***************************************************************
    // * =================== TURN ON Adapter ======================== *
    // ***************************************************************

    function test_imposterCantTurnOnAdapter() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        alloraAdapter.adminTurnOnAdapter();
    }

    function test_ownerCanTurnOnAdapter() public {
        vm.startPrank(admin);
        alloraAdapter.adminTurnOffAdapter();

        assertEq(alloraAdapter.switchedOn(), false);

        alloraAdapter.adminTurnOnAdapter();

        assertEq(alloraAdapter.switchedOn(), true);
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
                aggregator: aggregator,
                ownerSwitchedOn: true,
                adminSwitchedOn: true,
                dataProviderQuorum: 1,
                dataValiditySeconds: 5 minutes
            }),
            validDataProviders: oneValidProvider
        });
    }
}
