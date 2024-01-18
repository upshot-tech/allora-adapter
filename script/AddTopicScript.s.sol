// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import '../lib/forge-std/src/Script.sol';

import { AlloraAdapter } from '../src/AlloraAdapter.sol';
import { TopicConfig, TopicView } from '../src/interface/IAlloraAdapter.sol';
import { IAggregator } from '../src/interface/IAggregator.sol';
import { IFeeHandler } from '../src/interface/IFeeHandler.sol';
import { NumericData } from '../src/interface/IAlloraAdapter.sol';
import { ECDSA } from '../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

// run with 
// forge script ./script/AddTopicScript.s.sol:AddTopicScript --rpc-url <rpc url> --etherscan-api-key <etherscan api key> --broadcast --verify -vvvv

/**
 * @title AlloraAdapterViewPredictionExample
 * @notice Example contract adding topics to an AlloraAdapter
 */
contract AddTopicScript is Script {

    AlloraAdapter alloraAdapter = AlloraAdapter(0x9928f99dEf24e792cE8c20B7B67E64aafEC76c18);
    IAggregator aggregator = IAggregator(0x28bd0750FCAd5280464180b5Ac4860302dC7373c);

    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        string[8] memory topicTitles = [
            'Art Blocks Curated Index',
            'Yuga Index',
            'PFP Index',
            'Top 30 Liquid Collections Index',
            'Yuga Index - Grails',
            'Art Blocks Curated Index - Grails',
            'PFP Index - Grails',
            'CryptoDickbutt Appraisals'
        ];

        address[] memory validDataProviders = new address[](1);
        validDataProviders[0] = address(0xA459c3A3b7769e18E702a3B5e2dEcDD495655791);

        TopicView[] memory topicViews = new TopicView[](topicTitles.length);

        for (uint256 i = 0; i < topicTitles.length; i++) {
            topicViews[i] = TopicView({
                config: TopicConfig({
                    title: topicTitles[i],
                    owner: scriptRunner,
                    aggregator: aggregator,
                    ownerSwitchedOn: true,
                    adminSwitchedOn: true,
                    dataProviderQuorum: 1,
                    dataValiditySeconds: 1 hours
                }),
                validDataProviders: validDataProviders
            });
        }

        uint256[] memory topicIds = alloraAdapter.addTopics(topicViews);

        for (uint256 i = 0; i < topicTitles.length; i++) {
            console.log('Topic "%s" added with id %s', topicTitles[i], topicIds[i]);
        }

        vm.stopBroadcast();
    }
}
