// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import {EvenFeeHandler, EvenFeeHandlerConstructorArgs} from "../../src/feeHandler/EvenFeeHandler.sol";

contract EvenFeeHandlerTest is Test {
    EvenFeeHandler public evenFeeHandler;

    address admin = address(100);
    address feedOwner = address(101);

    address imposter = address(200);

    function setUp() public {
        evenFeeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin
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
        evenFeeHandler.handleFees{value: totalFee}(feedOwner, feeReceivers, "");

        assertEq(evenFeeHandler.feesAccrued(feedOwner), 0.0002 ether);

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

        evenFeeHandler.handleFees{value: 1 ether}(feedOwner, feeReceivers, "");

        assertEq(evenFeeHandler.feesAccrued(feedOwner), 0.2 ether);

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
        evenFeeHandler.handleFees{value: totalFee}(feedOwner, feeReceivers, "");

        uint256 feedOwnerBal0 = feedOwner.balance;
        uint256 feeReceiver1Bal0 = address(1).balance;
        uint256 feeReceiver2Bal0 = address(2).balance;
        uint256 feeReceiver3Bal0 = address(3).balance;

        vm.startPrank(feedOwner);
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


        assertEq(feedOwner.balance - feedOwnerBal0, 0.2 ether);
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
        evenFeeHandler.handleFees{value: 50}(feedOwner, feeReceivers, "");
    }

    function test_evenFeeHandlerCanHandleZeroFees() public {
        address[] memory feeReceivers = new address[](4);
        feeReceivers[0] = address(1);
        feeReceivers[1] = address(2);
        feeReceivers[2] = address(3);
        feeReceivers[3] = address(4);

        evenFeeHandler.handleFees{value: 0}(feedOwner, feeReceivers, "");

        assertEq(address(1).balance, 0 ether);
        assertEq(address(2).balance, 0 ether);
        assertEq(address(3).balance, 0 ether);
        assertEq(address(4).balance, 0 ether);
        assertEq(feedOwner.balance, 0 ether);
    }


    // ***************************************************************
    // * ============ UPDATE PROTOCOL FEE PORTION ================== *
    // ***************************************************************
    
    function test_imposterCantUpdateFeedOwnerFeePortion() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        evenFeeHandler.updateProtocolFeedOwnerPortion(0.1 ether);
    }

    function test_ownerCantUpdateFeedOwnerFeePortionToInvalidValue() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2EvenFeeHandlerInvalidFeedOwnerFeePortion()"));
        evenFeeHandler.updateProtocolFeedOwnerPortion(1.1 ether);
    }

    function test_ownerCanUpdateFeedOwnerFeePortion() public {
        vm.startPrank(admin);

        assertEq(evenFeeHandler.feedOwnerPortion(), 0.2 ether);

        evenFeeHandler.updateProtocolFeedOwnerPortion(0.3 ether);
        assertEq(evenFeeHandler.feedOwnerPortion(), 0.3 ether);
    }
}
