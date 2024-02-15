// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { AlloraAdapter, AlloraAdapterConstructorArgs } from "../src/AlloraAdapter.sol";
import { NumericData } from "../src/interface/IAlloraAdapter.sol";
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
        alloraAdapter = new AlloraAdapter(AlloraAdapterConstructorArgs({ owner: admin, aggregator: aggregator }));

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
    }

    // ***************************************************************
    // * ============= UPDATE DATA VALIDITY SECONDS ================ *
    // ***************************************************************

    function test_imposterCantUpdateDataValiditySeconds() public {
        vm.startPrank(imposter);

        vm.expectRevert("Ownable: caller is not the owner");
        alloraAdapter.updateDataValiditySeconds(10 minutes);
    }

    function test_ownerCantUpdateDataValiditySecondsToZero() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidDataValiditySeconds()"));
        alloraAdapter.updateDataValiditySeconds(0);
    }

    function test_ownerCanUpdateDataValiditySeconds() public {
        vm.startPrank(admin);

        assertEq(alloraAdapter.dataValiditySeconds(), 60 minutes);

        alloraAdapter.updateDataValiditySeconds(10 minutes);

        assertEq(alloraAdapter.dataValiditySeconds(), 10 minutes);
    }

    // ***************************************************************
    // * ==================== ADD DATA PROVIDER ==================== *
    // ***************************************************************

    function test_imposterCantAddDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert("Ownable: caller is not the owner");
        alloraAdapter.addDataProvider(imposter);
    }

    function test_ownerCanAddDataProvider() public {
        vm.startPrank(admin);

        assertEq(alloraAdapter.validDataProvider(newDataProvider), false);

        alloraAdapter.addDataProvider(newDataProvider);

        assertEq(alloraAdapter.validDataProvider(newDataProvider), true);
    }

    // ***************************************************************
    // * ================== REMOVE DATA PROVIDER =================== *
    // ***************************************************************

    function test_imposterCantRemoveDataProvider() public {
        vm.startPrank(imposter);

        vm.expectRevert("Ownable: caller is not the owner");
        alloraAdapter.removeDataProvider(imposter);
    }

    function test_ownerCanRemoveDataProvider() public {
        vm.startPrank(admin);

        alloraAdapter.addDataProvider(newDataProvider);

        assertEq(alloraAdapter.validDataProvider(newDataProvider), true);

        alloraAdapter.removeDataProvider(newDataProvider);

        assertEq(alloraAdapter.validDataProvider(newDataProvider), false);
    }

    // ***************************************************************
    // * ================= UPDATE AGGREGATOR ======================= *
    // ***************************************************************

    function test_imposterCantUpdateAggregator() public {
        vm.startPrank(imposter);

        vm.expectRevert("Ownable: caller is not the owner");
        alloraAdapter.updateAggregator(dummyAggregator);
    }

    function test_ownerCantUpdateAggregatorToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("AlloraAdapterV2InvalidAggregator()"));
        alloraAdapter.updateAggregator(IAggregator(address(0)));
    }

    function test_ownerCanUpdateAggregator() public {
        vm.startPrank(admin);

        MedianAggregator medianAggregator = new MedianAggregator();

        assertEq(address(alloraAdapter.aggregator()), address(aggregator));

        alloraAdapter.updateAggregator(medianAggregator);

        assertEq(address(alloraAdapter.aggregator()), address(medianAggregator));
    }

    // ***************************************************************
    // * ================== TURN OFF ADAPTER ======================== *
    // ***************************************************************

    function test_imposterCantTurnOffAdapter() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        alloraAdapter.turnOffAdapter();
    }

    function test_ownerCanTurnOffAdapter() public {
        vm.startPrank(admin);

        assertEq(alloraAdapter.switchedOn(), true);

        alloraAdapter.turnOffAdapter();

        assertEq(alloraAdapter.switchedOn(), false);
    }

    // ***************************************************************
    // * =================== TURN ON Adapter ======================== *
    // ***************************************************************

    function test_imposterCantTurnOnAdapter() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        alloraAdapter.turnOnAdapter();
    }

    function test_ownerCanTurnOnAdapter() public {
        vm.startPrank(admin);
        alloraAdapter.turnOffAdapter();

        assertEq(alloraAdapter.switchedOn(), false);

        alloraAdapter.turnOnAdapter();

        assertEq(alloraAdapter.switchedOn(), true);
    }
}
