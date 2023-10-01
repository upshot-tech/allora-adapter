// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import {Prices} from "../src/Prices.sol";
import {EvenFeeHandler} from "../src/feeHandler/EvenFeeHandler.sol";
import {AverageAggregator} from "../src/aggregator/AverageAggregator.sol";
import {IAggregator} from "../src/interface/IAggregator.sol";
import {IFeeHandler} from "../src/interface/IFeeHandler.sol";

contract EvenFeeHandlerTest is Test {
    EvenFeeHandler public evenFeeHandler;

    address admin = address(100);
    address protocolFeeReceiver = address(101);
    IAggregator aggregator;
    IFeeHandler feeHandler;
    Prices prices;

    function setUp() public {
        aggregator = new AverageAggregator();
        feeHandler = new EvenFeeHandler(admin, protocolFeeReceiver);
        prices = new Prices(admin, address(aggregator), address(feeHandler));

    }

    // ***************************************************************
    // * ===================== FUNCTIONALITY ======================= *
    // ***************************************************************
    function test_evenFeeHandlerHandleFees() public {

    }

    // ***************************************************************
    // * ============ UPDATE PROTOCOL FEE PORTION ================== *
    // ***************************************************************
    
    function test_imposterCantUpdateProtocolFeePortion() public {
        // vm.startPrank(imposter);

        // vm.expectRevert('Ownable: caller is not the owner');
        // evenFeeHandler.updateProtocolFeePortion(0.1 ether);
    }

    function test_ownerCantUpdateProtocolFeePortionToInvalidValue() public {
        // vm.startPrank(admin);

        // vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2EvenFeeHandlerInvalidProtocolFeePortion()"));
        // evenFeeHandler.updateProtocolFeePortion(1.1 ether);
    }

    function test_ownerCanUpdateProtocolFeePortion() public {
        // vm.startPrank(admin);

        // assertEq(evenFeeHandler.protocolFeePortion(), 0.2 ether);

        // evenFeeHandler.updateProtocolFeePortion(0.3 ether);
        // assertEq(evenFeeHandler.protocolFeePortion(), 0.3 ether);
    }

    // ***************************************************************
    // * ============ UPDATE PROTOCOL FEE RECEIVER ================= *
    // ***************************************************************
}
