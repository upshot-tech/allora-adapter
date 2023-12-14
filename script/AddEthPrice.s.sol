// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import '../lib/forge-std/src/Script.sol';

import { UpshotAdapter } from '../src/UpshotAdapter.sol';
import { TopicConfig, TopicView } from '../src/interface/IUpshotAdapter.sol';
import { IAggregator } from '../src/interface/IAggregator.sol';
import { IFeeHandler } from '../src/interface/IFeeHandler.sol';
import { NumericData, SignedNumericData, UpshotAdapterNumericData } from '../src/interface/IUpshotAdapter.sol';
import { ECDSA } from '../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

// run with 
// forge script ./script/AddEthPrice.s.sol:AddEthPrice --rpc-url <rpc url> --etherscan-api-key <etherscan api key> --broadcast --verify -vvvv


contract AddEthPrice is Script {
    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        UpshotAdapter upshotAdapter = UpshotAdapter(0x4Bb814869573de58F3789FA1F1ed60A0Ad3c1A2e);

        NumericData memory numericData = NumericData({
            topicId: 1,
            timestamp: 1702577000,
            numericValue: 2e18,
            extraData: ''
        });

        bytes32 message = upshotAdapter.getMessage(numericData);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            scriptRunnerPrivateKey, 
            ECDSA.toEthSignedMessageHash(message)
        );

        bytes memory signature = abi.encodePacked(r, s, v);

        SignedNumericData[] memory signedNumericData = new SignedNumericData[](1);

        signedNumericData[0] = SignedNumericData({
            signature: signature,
            numericData: numericData
        });

        upshotAdapter.verifyData(UpshotAdapterNumericData({
            signedNumericData: signedNumericData,
            extraData: ''
        }));

        vm.stopBroadcast();
    }
}
