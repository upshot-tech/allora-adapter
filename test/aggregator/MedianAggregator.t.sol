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

    function test_medianAggregator4() public {
        uint256[] memory values = new uint256[](5);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;
        values[3] = 4;
        values[4] = 5;
        assertEq(medianAggregator.aggregate(values, ""), 3);
    }

    function test_medianAggregator5() public {
        uint256[] memory values = new uint256[](6);
        values[0] = 1;
        values[1] = 2;
        values[2] = 3;
        values[3] = 4;
        values[4] = 5;
        values[5] = 6;
        assertEq(medianAggregator.aggregate(values, ""), 3);
    }

    function test_medianAggregator6() public {
        uint256[] memory values = new uint256[](6);
        values[0] = 5;
        values[1] = 5;
        values[2] = 5;
        values[3] = 5;
        values[4] = 5;
        values[5] = 5;
        assertEq(medianAggregator.aggregate(values, ""), 5);
    }

    function test_medianAggregator7() public {
        uint256[] memory values = new uint256[](6);
        values[0] = 1;
        values[1] = 1;
        values[2] = 2;
        values[3] = 2;
        values[4] = 2;
        values[5] = 2;
        assertEq(medianAggregator.aggregate(values, ""), 2);
    }

    function test_medianAggregator8() public {
        uint256[] memory values = new uint256[](6);
        values[0] = 8;
        values[1] = 2;
        values[2] = 9;
        values[3] = 20;
        values[4] = 13;
        values[5] = 6;
        assertEq(medianAggregator.aggregate(values, ""), 8);
    }

    function test_medianAggregator9() public {
        uint256[] memory values = new uint256[](5);
        values[0] = 8;
        values[1] = 6;
        values[2] = 9;
        values[3] = 20;
        values[4] = 13;
        assertEq(medianAggregator.aggregate(values, ""), 9);
    }

}
