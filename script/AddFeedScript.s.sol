// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import '../lib/forge-std/src/Script.sol';

import { Oracle } from '../src/Oracle.sol';
import { TopicConfig, TopicView } from '../src/interface/IOracle.sol';
import { IAggregator } from '../src/interface/IAggregator.sol';
import { IFeeHandler } from '../src/interface/IFeeHandler.sol';
import { NumericData } from '../src/interface/IOracle.sol';
import { ECDSA } from '../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';


// run with 
// forge script ./script/AddTopicScript.s.sol:AddTopicScript --rpc-url <rpc url> --broadcast --verify -vvvv


contract AddTopicScript is Script {
    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);
        Oracle oracle = Oracle(0xb5f9d3BeEdf68f4246a232d52Ae8f005e199B010);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        TopicConfig memory topicConfig = TopicConfig({
            title: 'HACKER FEED',
            owner: scriptRunner,
            totalFee: 0.01 ether,
            recentValueTime: 0,
            recentValue: 0,
            aggregator: IAggregator(0x3Ae558be9B1D540f83F0404de9C10eFb100D66B2),
            ownerSwitchedOn: true,
            adminSwitchedOn: true,
            feeHandler: IFeeHandler(0xa762c6288ad4CAB3750dC615c7cd531D99c6e169),
            dataProviderQuorum: 1,
            dataValiditySeconds: 1 hours
        });

        address[] memory validDataProviders = new address[](1);
        validDataProviders[0] = address(0xe3ceD0F62F7EB2856D37bEd128D2B195712d2644);

        TopicView memory topicView = TopicView({
            config: topicConfig,
            validDataProviders: validDataProviders
        });

        oracle.addTopic(topicView);

        vm.stopBroadcast();
    }
}
