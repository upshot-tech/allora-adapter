// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IAggregator {
    function aggregate(
        uint256[] memory values, 
        bytes memory extraData
    ) external view returns (uint256 value);
}
