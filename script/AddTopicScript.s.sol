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
    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);
        UpshotAdapter upshotAdapter = UpshotAdapter(0x238D0abD53fC68fAfa0CCD860446e381b400b5Be);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        string[] memory indices = new string[](7);
        indices[0] = 'Art Blocks Curated Index';
        indices[1] = 'Yuga Index';
        indices[2] = 'PFP Index';
        indices[3] = 'Top 30 Liquid Collections Index';
        indices[4] = 'Yuga Index - Grails';
        indices[5] = 'Art Blocks Curated Index - Grails';
        indices[6] = 'PFP Index - Grails';

        for (uint256 i = 0; i < indices.length; i++) {
            TopicConfig memory topicConfig = TopicConfig({
                title: indices[i],
                owner: scriptRunner,
                totalFee: 0 ether,
                recentValueTime: 0,
                recentValue: 0,
                aggregator: IAggregator(0x180A7132C54Eb5e88fbda5b764580B8cBa4c7958),
                ownerSwitchedOn: true,
                adminSwitchedOn: true,
                feeHandler: IFeeHandler(0x594F9D4d09E6daEe8C35b30bCB5c3a1269d2B712),
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
        }

/*
        TopicConfig memory topicConfig = TopicConfig({
            title: 'Art Blocks Curated Index',
            owner: scriptRunner,
            totalFee: 0 ether,
            recentValueTime: 0,
            recentValue: 0,
            aggregator: IAggregator(0x180A7132C54Eb5e88fbda5b764580B8cBa4c7958),
            ownerSwitchedOn: true,
            adminSwitchedOn: true,
            feeHandler: IFeeHandler(0x594F9D4d09E6daEe8C35b30bCB5c3a1269d2B712),
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
*/

        vm.stopBroadcast();
    }
}
