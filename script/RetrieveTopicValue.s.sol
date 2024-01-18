// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../lib/forge-std/src/Script.sol';

import { IAlloraAdapter, Topic, TopicValue, TopicConfig, AlloraAdapterNumericData } from '../src/interface/IAlloraAdapter.sol';
import { Ownable2Step } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

// forge script ./script/RetrieveTopicValue.s.sol:RetrieveTopicValue --rpc-url <rpc url> --etherscan-api-key <etherscan api key> --broadcast --verify -vvvv

/**
 * @title RetrieveTopicValue
 * @notice Example contract for viewing a prediction for a topic 
 */
contract RetrieveTopicValue is Script {

    // Sepolia adapter Address
    IAlloraAdapter constant ALLORA_ADAPTER = IAlloraAdapter(0x238D0abD53fC68fAfa0CCD860446e381b400b5Be);
    uint256 constant TOPIC_ID = 1;

    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', vm.addr(scriptRunnerPrivateKey));

        TopicValue memory topicValue = ALLORA_ADAPTER.getTopicValue(TOPIC_ID, '');

        console.log('Recent Value: %d', topicValue.recentValue);
        console.log('Recent Value Timestamp: %d', topicValue.recentValueTime);
    }
}
