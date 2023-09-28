// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IAggregator } from '../interface/IAggregator.sol';

contract AverageAggregator is IAggregator {
    function aggregate(
        uint256[] memory values, 
        bytes memory
    ) external pure returns (uint256 value) {
        uint256 sum = 0;
        uint256 countValues = values.length;
        for (uint256 i = 0; i < countValues; i++) {
            sum += values[i];
        }
        return sum / countValues;
    }
}
