// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IAggregator } from '../interface/IAggregator.sol';
import { Math } from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract MedianAggregator is IAggregator {
    function aggregate(
        uint256[] memory values, 
        bytes memory
    ) external pure returns (uint256) {
        uint256 count = values.length;
        require(count > 0, 'empty');

        uint256 value;
        uint256 min;
        uint256 max;
        // calculate median by removing the min and max value until there is only one or two values left.
        while(count > 2) {
            // first, find the min and max values
            min = values[0];
            max = values[0];
            for(uint256 i = 1; i < count; i++) {
                value = values[i];
                if (value < min) min = value;
                if (value > max) max = value;
            }
            // if all the values are the same then our task is easy.
            if (min == max) return min;

            // now, remove the min and max.
            uint[] memory newValues = new uint[](count - 2);
            uint256 j;
            bool maxRemoved;
            bool minRemoved;
            for(uint256 i = 0; i < count; i++) {
                value = values[i];
                if (value == min && !minRemoved) minRemoved = true;
                else if (value == max && !maxRemoved) maxRemoved = true;
                else newValues[j++] = value;
            }
            count -= 2;
            values = newValues;
        }

        // return the single value or the average of the two remaining
        if (count == 1) return values[0];
        else return Math.average(values[0], values[1]);
    }
}
