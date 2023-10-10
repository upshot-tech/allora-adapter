// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import '../lib/forge-std/src/Script.sol';

import { Oracle } from '../src/Oracle.sol';
import { NumericData } from '../src/interface/IOracle.sol';
import { ECDSA } from '../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';


contract OracleScript is Script {
    function run() public virtual {
        uint256 scriptRunnerPrivateKey = vm.envUint('DEPLOYER_PRIVATE_KEY');
        address scriptRunner = vm.addr(scriptRunnerPrivateKey);
        // Oracle oracle = Oracle(0xc01750713d34505171c3d66046D3b04C6fFb9cEC);

        vm.startBroadcast(scriptRunnerPrivateKey);
        console.log('Broadcast started by %s', scriptRunner);

        vm.stopBroadcast();
    }
}
