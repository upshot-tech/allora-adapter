// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import '../lib/forge-std/src/Script.sol';

import { AlloraAdapter } from '../src/AlloraAdapter.sol';
import { IAggregator } from '../src/interface/IAggregator.sol';
import { IFeeHandler } from '../src/interface/IFeeHandler.sol';
import { NumericData, AlloraAdapterNumericData, SignedNumericData } from '../src/interface/IAlloraAdapter.sol';
import { ECDSA } from '../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

// run with 
// forge script ./script/VerifyDataExample.s.sol:VerifyDataExample --rpc-url <rpc url> --etherscan-api-key <etherscan api key> --broadcast --verify -vvvv

contract VerifyDataExample is Script {

    AlloraAdapter alloraAdapter = AlloraAdapter(0x238D0abD53fC68fAfa0CCD860446e381b400b5Be);

    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('SCRIPT_RUNNER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        NumericData memory numericData = NumericData({
            topicId: 1,
            timestamp: block.timestamp - 5 minutes,
            numericValue: 123456789012345678,
            extraData: ''
        });

        bytes32 message = alloraAdapter.getMessage(numericData);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            scriptRunnerPrivateKey, 
            ECDSA.toEthSignedMessageHash(message)
        );

        SignedNumericData[] memory signedNumericData = new SignedNumericData[](1);

        signedNumericData[0] = SignedNumericData({
            signature: abi.encodePacked(r, s, v),
            numericData: numericData
        });

        alloraAdapter.verifyData(AlloraAdapterNumericData({
            signedNumericData: signedNumericData,
            extraData: ''
        }));

        vm.stopBroadcast();
    }

    function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}
