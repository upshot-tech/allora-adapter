// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import {EvenFeeHandler} from "../../src/feeHandler/EvenFeeHandler.sol";

contract EvenFeeHandlerTest is Test {
    EvenFeeHandler public evenFeeHandler;

    address admin = address(100);
    address protocolFeeReceiver = address(101);
    address protocolFeeReceiver2 = address(102);
    address imposter = address(200);

    function setUp() public {
        evenFeeHandler = new EvenFeeHandler(admin, protocolFeeReceiver);
    }

    // ***************************************************************
    // * ===================== FUNCTIONALITY ======================= *
    // ***************************************************************
    function test_evenFeeHandlerHandleFees() public {
        address[] memory feeReceivers = new address[](2);
        feeReceivers[0] = address(1);
        feeReceivers[1] = address(2);
        uint256 totalFee = 0.001 ether;
        evenFeeHandler.handleFees{value: totalFee}(feeReceivers, "");

        assertEq(protocolFeeReceiver.balance, 0.0002 ether);

        assertEq(address(1).balance, 0.0004 ether);
        assertEq(address(2).balance, 0.0004 ether);
    }

    function test_evenFeeHandlerHandleFees2() public {
        address[] memory feeReceivers = new address[](4);
        feeReceivers[0] = address(1);
        feeReceivers[1] = address(2);
        feeReceivers[2] = address(3);
        feeReceivers[3] = address(4);

        evenFeeHandler.handleFees{value: 1 ether}(feeReceivers, "");

        assertEq(protocolFeeReceiver.balance, 0.2 ether);

        assertEq(address(1).balance, 0.2 ether);
        assertEq(address(2).balance, 0.2 ether);
        assertEq(address(3).balance, 0.2 ether);
        assertEq(address(4).balance, 0.2 ether);
    }

    // ***************************************************************
    // * ============ UPDATE PROTOCOL FEE PORTION ================== *
    // ***************************************************************
    
    function test_imposterCantUpdateProtocolFeePortion() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        evenFeeHandler.updateProtocolFeePortion(0.1 ether);
    }

    function test_ownerCantUpdateProtocolFeePortionToInvalidValue() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleEvenFeeHandlerInvalidProtocolFeePortion()"));
        evenFeeHandler.updateProtocolFeePortion(1.1 ether);
    }

    function test_ownerCanUpdateProtocolFeePortion() public {
        vm.startPrank(admin);

        assertEq(evenFeeHandler.protocolFeePortion(), 0.2 ether);

        evenFeeHandler.updateProtocolFeePortion(0.3 ether);
        assertEq(evenFeeHandler.protocolFeePortion(), 0.3 ether);
    }

    // ***************************************************************
    // * ============ UPDATE PROTOCOL FEE RECEIVER ================= *
    // ***************************************************************

    function test_imposterCantUpdateProtocolFeeReceiver() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        evenFeeHandler.updateProtocolFeeReceiver(protocolFeeReceiver2);
    }

    function test_ownerCanUpdateProtocolFeeReciever() public {
        vm.startPrank(admin);

        assertEq(evenFeeHandler.protocolFeeReceiver(), protocolFeeReceiver);

        evenFeeHandler.updateProtocolFeeReceiver(protocolFeeReceiver2);
        assertEq(evenFeeHandler.protocolFeeReceiver(), protocolFeeReceiver2);
    }
}
