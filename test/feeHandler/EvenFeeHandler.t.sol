// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {Test, console2} from "../../lib/forge-std/src/Test.sol";
import {EvenFeeHandler} from "../../src/feeHandler/EvenFeeHandler.sol";

contract EvenFeeHandlerTest is Test {
    EvenFeeHandler public evenFeeHandler;

    address admin = address(100);
    address protocolFeeReceiver = address(101);

    function setUp() public {
        evenFeeHandler = new EvenFeeHandler(admin, protocolFeeReceiver);
    }

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
}
