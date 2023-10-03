// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IAggregator } from '../interface/IAggregator.sol';
import { Math } from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @title MedianAggregator
 * @notice Aggregator that returns the median of the values
 */
contract MedianAggregator is IAggregator {

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error UpshotOracleV2MedianAggregatorNoValuesToAggregate();

    // ***************************************************************
    // * ===================== USER INTERFACE ====================== *
    // ***************************************************************

    /// @inheritdoc IAggregator
    function aggregate(
        uint256[] memory values, 
        bytes memory
    ) external pure returns (uint256) {
        uint256 count = values.length;

        if (count == 0) {
            revert UpshotOracleV2MedianAggregatorNoValuesToAggregate();
        }

        uint256 value;
        uint256 min;
        uint256 max;
        // calculate median by removing the min and max value until there is only one or two values left.
        while(count > 2) {
            // first, find the min and max values
            min = values[0];
            max = values[0];
            for(uint256 i = 1; i < count;) {
                value = values[i];
                if (value < min) min = value;
                if (value > max) max = value;

                unchecked {
                    ++i;
                }
            }
            // if all the values are the same then our task is easy.
            if (min == max) return min;

            // now, remove the min and max.
            uint256[] memory newValues = new uint256[](count - 2);
            uint256 j = 0;
            bool maxRemoved;
            bool minRemoved;
            for(uint256 i = 0; i < count;) {
                value = values[i];
                if (value == min && !minRemoved) minRemoved = true;
                else if (value == max && !maxRemoved) maxRemoved = true;
                else newValues[j++] = value;

                unchecked {
                    ++i;
                }
            }
            count -= 2;
            values = newValues;
        }

        // return the single value or the average of the two remaining
        return count == 1 ? values[0] : Math.average(values[0], values[1]);
    }
}
