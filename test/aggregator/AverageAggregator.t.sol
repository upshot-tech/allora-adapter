// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {Test, console2} from "../../lib/forge-std/src/Test.sol";
import {AverageAggregator} from "../../src/aggregator/AverageAggregator.sol";

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

    function test_averageAggregatorFuzz(uint248 a, uint248 b, uint248 c) public {
        uint256[] memory values = new uint256[](3);
        values[0] = a;
        values[1] = b;
        values[2] = c;

        assertEq(averageAggregator.aggregate(values, ""), (uint256(a) + uint256(b) + uint256(c)) / 3);
    }

    function test_averageAggregatorNoValues() public {
        uint256[] memory values = new uint256[](0);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2AverageAggregatorNoValuesToAggregate()"));
        averageAggregator.aggregate(values, "");
    }
}
