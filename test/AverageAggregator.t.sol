// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {AverageAggregator} from "../src/aggregator/AverageAggregator.sol";

contract AverageAggregatorTest is Test {
    AverageAggregator public averageAggregator;

    function setUp() public {
        averageAggregator = new AverageAggregator();
    }

    function test_averageAggregator() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;
        assertEq(averageAggregator.aggregate(values, ""), 2);
    }
}
