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

        UpshotAdapter upshotAdapter = UpshotAdapter(0x238D0abD53fC68fAfa0CCD860446e381b400b5Be);

        NumericData memory numericData = NumericData({
            topicId: 1,
            timestamp: 1704318000,
            numericValue: 123456789012345678,
            extraData: ''
        });

        bytes32 message = upshotAdapter.getMessage(numericData);

        console.log('Message: %s', _bytes32ToHexString(message));
        console.log('scriptRunnerPrivateKey: %s', _bytes32ToHexString(bytes32(uint256(scriptRunnerPrivateKey))));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            scriptRunnerPrivateKey, 
            ECDSA.toEthSignedMessageHash(message)
        );

        bytes memory signature = abi.encodePacked(r, s, v);

        console.log('Signature: %s', _bytesToHexString(signature));

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

    function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function _bytes32ToHexString(bytes32 _bytes32) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory hexString = new bytes(66); // 2 characters per byte + '0x' prefix
        hexString[0] = '0';
        hexString[1] = 'x';

        for (uint i = 0; i < 32; i++) {
            hexString[2+i*2] = hexChars[uint8(_bytes32[i] >> 4)];
            hexString[3+i*2] = hexChars[uint8(_bytes32[i] & 0x0f)];
        }

        return string(hexString);

    }

    function _bytesToHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory hexString = new bytes(2 * data.length + 2); // 2 characters per byte + '0x' prefix
        hexString[0] = '0';
        hexString[1] = 'x';

        for (uint i = 0; i < data.length; i++) {
            hexString[2+i*2] = hexChars[uint8(data[i] >> 4)];
            hexString[2+i*2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }

        return string(hexString);
    }

}
