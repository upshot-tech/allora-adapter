// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IAggregator } from '../interface/IAggregator.sol';

/**
 * @title AverageAggregator
 * @notice Aggregator that returns the average of the values
 */
contract AverageAggregator is IAggregator {

    // ***************************************************************
    // * ========================= ERRORS ========================== *
    // ***************************************************************

    error AlloraAdapterV2AverageAggregatorNoValuesToAggregate();

    // ***************************************************************
    // * ===================== USER INTERFACE ====================== *
    // ***************************************************************

    /// @inheritdoc IAggregator
    function aggregate(
        uint256[] memory values, 
        bytes memory
    ) external pure returns (uint256 value) {
        uint256 countValues = values.length;
        if (countValues == 0) {
            revert AlloraAdapterV2AverageAggregatorNoValuesToAggregate();
        }

        uint256 sum = 0;
        for (uint256 i = 0; i < countValues;) {
            sum += values[i];

            unchecked {
                ++i;
            }
        }

        return sum / countValues;
    }
}
