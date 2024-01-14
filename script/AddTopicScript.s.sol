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

/**
 * @title UpshotAdapterViewPredictionExample
 * @notice Example contract adding topics to an UpshotAdapter
 */
contract AddTopicScript is Script {

    UpshotAdapter upshotAdapter = UpshotAdapter(0x4341a3F0a350C2428184a727BAb86e16D4ba7018);
    IAggregator aggregator = IAggregator(0x3eB08C166509638669e78d0c50c0f82A25Bc8e46);
    IFeeHandler feeHandler = IFeeHandler(0x97E4F3C818F8F2E5e7Caa3e16DFC060D7c49bB43);

    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        string[7] memory topicTitles = [
            'Art Blocks Curated Index',
            'Yuga Index',
            'PFP Index',
            'Top 30 Liquid Collections Index',
            'Yuga Index - Grails',
            'Art Blocks Curated Index - Grails',
            'PFP Index - Grails'
        ];

        TopicView[] memory topicViews = new TopicView[](topicTitles.length);

        TopicConfig memory topicConfig = TopicConfig({
            title: '',
            owner: scriptRunner,
            totalFee: 0 ether,
            aggregator: aggregator,
            ownerSwitchedOn: true,
            adminSwitchedOn: true,
            feeHandler: feeHandler,
            dataProviderQuorum: 1,
            dataValiditySeconds: 1 hours
        });

        address[] memory validDataProviders = new address[](1);
        validDataProviders[0] = address(0xA459c3A3b7769e18E702a3B5e2dEcDD495655791);

        TopicView memory topicView = TopicView({
            config: topicConfig,
            validDataProviders: validDataProviders
        });

        for (uint256 i = 0; i < topicTitles.length; i++) {
            topicViews[i] = topicView;
            topicViews[i].config.title = topicTitles[i];
        }

        uint256[] memory topicIds = upshotAdapter.addTopics(topicViews);

        for (uint256 i = 0; i < topicTitles.length; i++) {
            console.log('Topic "%s" added with id %s', topicTitles[i], topicIds[i]);
        }

        vm.stopBroadcast();
    }
}
