// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import '../lib/forge-std/src/Script.sol';

import { UpshotAdapter } from '../src/UpshotAdapter.sol';
import { TopicConfig, TopicView } from '../src/interface/IUpshotAdapter.sol';
import { IAggregator } from '../src/interface/IAggregator.sol';
import { IFeeHandler } from '../src/interface/IFeeHandler.sol';
import { NumericData } from '../src/interface/IUpshotAdapter.sol';
import { ECDSA } from '../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

// run with 
// forge script ./script/AddTopicScript.s.sol:AddTopicScript --rpc-url <rpc url> --etherscan-api-key <etherscan api key> --broadcast --verify -vvvv


contract AddTopicScript is Script {
    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);
        UpshotAdapter upshotAdapter = UpshotAdapter(0x766662c5078515A9D22A71ab695206aCD18dD44C);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        TopicConfig memory topicConfig = TopicConfig({
            title: 'Eth/USD Price feed, 18 decimals',
            owner: scriptRunner,
            totalFee: 0 ether,
            recentValueTime: 0,
            recentValue: 0,
            aggregator: IAggregator(0xdC31B5eA06389A124ff3cFBD71fdC35DA5A64f47),
            ownerSwitchedOn: true,
            adminSwitchedOn: true,
            feeHandler: IFeeHandler(0xeD3b6e434eBd994Ff42Bc1088fB062f8faa4f893),
            dataProviderQuorum: 1,
            dataValiditySeconds: 1 hours
        });

        address[] memory validDataProviders = new address[](1);
        validDataProviders[0] = address(0xA459c3A3b7769e18E702a3B5e2dEcDD495655791);

        TopicView memory topicView = TopicView({
            config: topicConfig,
            validDataProviders: validDataProviders
        });

        uint256 topicId = upshotAdapter.addTopic(topicView);
        console.log('Topic generated with id %s', topicId);

        vm.stopBroadcast();
    }
}
