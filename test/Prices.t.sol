// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Prices} from "../src/Prices.sol";
import {PriceData} from "../src/interface/IPrices.sol";
import {EvenFeeHandler} from "../src/feeHandler/EvenFeeHandler.sol";
import {AverageAggregator} from "../src/aggregator/AverageAggregator.sol";
import {IAggregator} from "../src/interface/IAggregator.sol";
import {IFeeHandler} from "../src/interface/IFeeHandler.sol";

struct PriceDataWithoutSignature {
    uint256 feedId;
    uint256 nonce;
    uint96 timestamp;
    uint256 price; 
    bytes extraData;
}

contract EvenFeeHandlerTest is Test {
    EvenFeeHandler public evenFeeHandler;

    address admin = address(100);
    address protocolFeeReceiver = address(101);
    IAggregator aggregator;
    IFeeHandler feeHandler;
    Prices prices;

    uint256 signer0pk = 0x1000;
    uint256 signer1pk = 0x1001;
    uint256 signer2pk = 0x1002;

    address signer0;
    address signer1;
    address signer2;


    function setUp() public {
        vm.warp(1 hours);

        aggregator = new AverageAggregator();
        feeHandler = new EvenFeeHandler(admin, protocolFeeReceiver);
        prices = new Prices(admin, address(aggregator), address(feeHandler));

        signer0 = vm.addr(signer0pk);
        signer1 = vm.addr(signer1pk);
        signer2 = vm.addr(signer2pk);
    }

    // ***************************************************************
    // * ===================== FUNCTIONALITY ======================= *
    // ***************************************************************
    function test_cantCallGetPriceWhenContractSwitchedOff() public {
        vm.startPrank(admin);
        vm.deal(admin, 2^128);
        prices.turnOff();
        
        PriceData[] memory priceData = new PriceData[](0);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2NotSwitchedOn()"));
        prices.getPrice(priceData, '');
    }

    function test_cantCallGetPriceWithoutFee() public {
        PriceData[] memory priceData = new PriceData[](0);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InsufficientPayment()"));
        prices.getPrice(priceData, '');
    }

    function test_cantCallGetPriceWithoutThresholdCountPriceFeeds() public {
        PriceData[] memory priceData = new PriceData[](0);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2NotEnoughPrices()"));
        prices.getPrice{value: 1 ether}(priceData, '');
    }

    function test_canCallGetPriceWithValidSignature() public {
        vm.startPrank(admin);
        prices.addFeed('Initial feed');
        prices.addValidSigner(signer0);
        vm.stopPrank();

        PriceData[] memory priceData = new PriceData[](1);

        priceData[0] = _getPriceData(
            PriceDataWithoutSignature({
                feedId: 1,
                nonce: 2,
                timestamp: uint96(block.timestamp - 1 minutes),
                price: 1 ether,
                extraData: ''
            }),
            signer0pk
        );

        prices.getPrice{value: 1 ether}(priceData, '');
    }

    function _getPriceData(
        PriceDataWithoutSignature memory priceDataIn,
        uint256 signerPk
    ) internal view returns (PriceData memory) {
        bytes32 priceMessage = prices.getPriceMessage(
            priceDataIn.feedId,
            priceDataIn.nonce,
            priceDataIn.timestamp,
            priceDataIn.price,
            priceDataIn.extraData
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPk,
            ECDSA.toEthSignedMessageHash(priceMessage)
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        return PriceData({
            signature: signature,
            feedId: priceDataIn.feedId,
            nonce: priceDataIn.nonce,
            timestamp: priceDataIn.timestamp,
            price: priceDataIn.price,
            extraData: priceDataIn.extraData
        });
    }
}
