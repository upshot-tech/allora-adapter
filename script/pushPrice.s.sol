// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../lib/forge-std/src/Script.sol";

import {Prices} from "../src/Prices.sol";
import {PriceData} from "../src/interface/IPrices.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

struct PriceDataWithoutSignature {
    uint256 feedId;
    uint256 nonce;
    uint96 timestamp;
    uint256 price; 
    bytes extraData;
}

contract PushPrice is Script {

    function run() public virtual {
        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddr = vm.addr(privateKey);

        Prices prices = Prices(0xc01750713d34505171c3d66046D3b04C6fFb9cEC);

        vm.startBroadcast(privateKey);

        // Add deployer as valid price authority
        prices.addValidSigner(deployerAddr);

        // create a new feed to push prices to 
        uint256 feedId = prices.addFeed("HACKER FEED");

        // set up encoding to push a price of 1.337 ether to the HACKER FEED
        PriceDataWithoutSignature memory pdws = PriceDataWithoutSignature({
                feedId: feedId,
                nonce: 2,
                timestamp: uint96(block.timestamp - 1 minutes),
                price: 1.337 ether,
                extraData: ''
            });
        bytes32 priceMessage = prices.getPriceMessage(
            pdws.feedId,
            pdws.nonce,
            pdws.timestamp,
            pdws.price,
            pdws.extraData
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            ECDSA.toEthSignedMessageHash(priceMessage)
        );
        bytes memory signature = abi.encodePacked(r, s, v);
        PriceData memory pd = PriceData({
            signature: signature,
            feedId: pdws.feedId,
            nonce: pdws.nonce,
            timestamp: pdws.timestamp,
            price: pdws.price,
            extraData: pdws.extraData
        });
        PriceData[] memory pds = new PriceData[](1);
        pds[0] = pd;


        // send the actual TX that pushes the price, paying 1 eth as fee
        uint256 price = prices.getPrice{value: 1 ether}(pds, '');

        console.log("Oracle price %s", price);
        vm.stopBroadcast();
    }
}