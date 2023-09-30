// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {Test, console2} from "../../lib/forge-std/src/Test.sol";
import {MedianAggregator} from "../../src/aggregator/MedianAggregator.sol";

contract MedianAggregatorTest is Test {
    MedianAggregator public medianAggregator;

    function setUp() public {
        medianAggregator = new MedianAggregator();
    }

    function test_medianAggregator() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;
        assertEq(medianAggregator.aggregate(values, ""), 2);
    }
    
    function test_medianAggregator2() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 2;
        values[2] = 4;
        assertEq(medianAggregator.aggregate(values, ""), 2);
    }

    function test_medianAggregator3() public {
        uint256[] memory values = new uint256[](2);
        values[0] = 4;
        values[1] = 2;
        assertEq(medianAggregator.aggregate(values, ""), 3);
    }

    // TODO additional tests
}
