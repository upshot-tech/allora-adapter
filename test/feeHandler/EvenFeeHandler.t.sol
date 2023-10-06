// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import {EvenFeeHandler, EvenFeeHandlerConstructorArgs} from "../../src/feeHandler/EvenFeeHandler.sol";

contract EvenFeeHandlerTest is Test {
    EvenFeeHandler public evenFeeHandler;

    address admin = address(100);
    address protocolFeeReceiver = address(101);
    address protocolFeeReceiver2 = address(102);
    address imposter = address(200);

    function setUp() public {
        evenFeeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin,
            protocolFeeReceiver: protocolFeeReceiver
        }));
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

        assertEq(evenFeeHandler.feesAccrued(protocolFeeReceiver), 0.0002 ether);

        assertEq(evenFeeHandler.feesAccrued(address(1)), 0.0004 ether);
        assertEq(evenFeeHandler.feesAccrued(address(2)), 0.0004 ether);
        assertEq(evenFeeHandler.feesAccrued(address(3)), 0 ether);
    }

    function test_evenFeeHandlerHandleFees2() public {
        address[] memory feeReceivers = new address[](4);
        feeReceivers[0] = address(1);
        feeReceivers[1] = address(2);
        feeReceivers[2] = address(3);
        feeReceivers[3] = address(4);

        evenFeeHandler.handleFees{value: 1 ether}(feeReceivers, "");

        assertEq(evenFeeHandler.feesAccrued(protocolFeeReceiver), 0.2 ether);

        assertEq(evenFeeHandler.feesAccrued(address(1)), 0.2 ether);
        assertEq(evenFeeHandler.feesAccrued(address(2)), 0.2 ether);
        assertEq(evenFeeHandler.feesAccrued(address(3)), 0.2 ether);
        assertEq(evenFeeHandler.feesAccrued(address(4)), 0.2 ether);
        assertEq(evenFeeHandler.feesAccrued(address(5)), 0 ether);
    }

    function test_evenFeeHandlerClaimFees() public {
        address[] memory feeReceivers = new address[](2);
        feeReceivers[0] = address(1);
        feeReceivers[1] = address(2);
        uint256 totalFee = 1 ether;
        evenFeeHandler.handleFees{value: totalFee}(feeReceivers, "");

        uint256 protocolFeeReceiverBal0 = protocolFeeReceiver.balance;
        uint256 feeReceiver1Bal0 = address(1).balance;
        uint256 feeReceiver2Bal0 = address(2).balance;
        uint256 feeReceiver3Bal0 = address(3).balance;

        vm.startPrank(protocolFeeReceiver);
        evenFeeHandler.claimFees();
        vm.stopPrank();

        vm.startPrank(address(1));
        evenFeeHandler.claimFees();
        vm.stopPrank();

        vm.startPrank(address(2));
        evenFeeHandler.claimFees();
        vm.stopPrank();

        vm.startPrank(address(3));
        evenFeeHandler.claimFees();
        vm.stopPrank();


        assertEq(protocolFeeReceiver.balance - protocolFeeReceiverBal0, 0.2 ether);
        assertEq(address(1).balance - feeReceiver1Bal0, 0.4 ether);
        assertEq(address(2).balance - feeReceiver2Bal0, 0.4 ether);
        assertEq(address(3).balance - feeReceiver3Bal0, 0 ether);
    }

    function test_evenFeeHandlerCantHandleTinyFees() public {
        address[] memory feeReceivers = new address[](4);
        feeReceivers[0] = address(1);
        feeReceivers[1] = address(2);
        feeReceivers[2] = address(3);
        feeReceivers[3] = address(4);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2EvenFeeHandlerFeeTooLow()"));
        evenFeeHandler.handleFees{value: 50}(feeReceivers, "");
    }

    function test_evenFeeHandlerCanHandleZeroFees() public {
        address[] memory feeReceivers = new address[](4);
        feeReceivers[0] = address(1);
        feeReceivers[1] = address(2);
        feeReceivers[2] = address(3);
        feeReceivers[3] = address(4);

        evenFeeHandler.handleFees{value: 0}(feeReceivers, "");

        assertEq(address(1).balance, 0 ether);
        assertEq(address(2).balance, 0 ether);
        assertEq(address(3).balance, 0 ether);
        assertEq(address(4).balance, 0 ether);
        assertEq(protocolFeeReceiver.balance, 0 ether);
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

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2EvenFeeHandlerInvalidProtocolFeePortion()"));
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
