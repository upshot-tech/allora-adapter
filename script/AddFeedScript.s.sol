// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import '../lib/forge-std/src/Script.sol';

import { Oracle } from '../src/Oracle.sol';
import { FeedConfig, FeedView } from '../src/interface/IOracle.sol';
import { IAggregator } from '../src/interface/IAggregator.sol';
import { IFeeHandler } from '../src/interface/IFeeHandler.sol';
import { NumericData } from '../src/interface/IOracle.sol';
import { ECDSA } from '../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';


// run with forge script ./script/AddFeedScript.s.sol:AddFeedScript --rpc-url https://eth-sepolia.g.alchemy.com/v2/pmw7pjM7F-GtiJLxKnOBcOP41znmwVeY --broadcast --verify -vvvv


contract AddFeedScript is Script {
    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);
        Oracle oracle = Oracle(0x7ec114a7682a3441d4b6595FB067d7b1Faa255Ca);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        FeedConfig memory feedConfig = FeedConfig({
            title: 'HACKER FEED',
            owner: scriptRunner,
            totalFee: 0.01 ether,
            aggregator: IAggregator(0x877Fb79de29C8f65d89Af7e69627Ae9d2C466Bf1),
            ownerSwitchedOn: true,
            adminSwitchedOn: true,
            feeHandler: IFeeHandler(0x805F824C3342187122B1d22AFadc17A4Ab5845c9),
            dataProviderQuorum: 1,
            dataValiditySeconds: 1 hours
        });

        address[] memory validDataProviders = new address[](1);
        validDataProviders[0] = address(0xe3ceD0F62F7EB2856D37bEd128D2B195712d2644);

        FeedView memory feedView = FeedView({
            config: feedConfig,
            validDataProviders: validDataProviders
        });

        oracle.addFeed(feedView);

        vm.stopBroadcast();
    }
}
