// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Prices} from "../src/Prices.sol";
import {PriceData, Feed} from "../src/interface/IPrices.sol";
import {EvenFeeHandler} from "../src/feeHandler/EvenFeeHandler.sol";
import {AverageAggregator} from "../src/aggregator/AverageAggregator.sol";
import {MedianAggregator} from "../src/aggregator/MedianAggregator.sol";
import {IAggregator} from "../src/interface/IAggregator.sol";
import {IFeeHandler} from "../src/interface/IFeeHandler.sol";

struct PriceDataWithoutSignature {
    uint256 feedId;
    uint256 nonce;
    uint96 timestamp;
    uint256 price; 
    bytes extraData;
}

contract PricesAdmin is Test {

    EvenFeeHandler public evenFeeHandler;
    IAggregator aggregator;
    IFeeHandler feeHandler;
    Prices prices;

    address admin = address(100);
    address protocolFeeReceiver = address(101);

    address imposter = address(200);
    address newSigner = address(201);
    address dummyAggregator = address(202);
    address dummyFeeHandler = address(202);

    function setUp() public {
        vm.warp(1 hours);

        aggregator = new AverageAggregator();
        feeHandler = new EvenFeeHandler(admin, protocolFeeReceiver);
        prices = new Prices(admin, address(aggregator), address(feeHandler));
    }

    // ***************************************************************
    // * =================== UPDATE MIN PRICES ===================== *
    // ***************************************************************

    function test_imposterCantUpdateMinPrices() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updateMinPrices(3);
    }

    function test_ownerCantUpdateMinPricesToZero() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2PricesInvalidMinPrices()"));
        prices.updateMinPrices(0);
    }

    function test_ownerCanUpdateMinPrices() public {
        vm.startPrank(admin);

        assertEq(prices.minPrices(), 1);

        prices.updateMinPrices(2);
        assertEq(prices.minPrices(), 2);
    }

    // ***************************************************************
    // * ============= UPDATE PRICE VALIDITY SECONDS =============== *
    // ***************************************************************

    function test_imposterCantUpdatePriceValiditySeconds() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updatePriceValiditySeconds(10 minutes);
    }

    function test_ownerCantUpdatePriceValiditySecondsToZero() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidPriceValiditySeconds()"));
        prices.updatePriceValiditySeconds(0);
    }

    function test_ownerCanUpdatePriceValiditySeconds() public {
        vm.startPrank(admin);

        assertEq(prices.priceValiditySeconds(), 5 minutes);

        prices.updatePriceValiditySeconds(10 minutes);
        assertEq(prices.priceValiditySeconds(), 10 minutes);
    }

    // ***************************************************************
    // * ==================== ADD VALID SIGNER ===================== *
    // ***************************************************************

    function test_imposterCantAddValidSigner() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.addValidSigner(imposter);
    }

    function test_ownerCanAddValidSigner() public {
        vm.startPrank(admin);

        assertEq(prices.validSigner(newSigner), false);

        prices.addValidSigner(newSigner);
        assertEq(prices.validSigner(newSigner), true);
    }

    // ***************************************************************
    // * ================== REMOVE VALID SIGNER ==================== *
    // ***************************************************************

    function test_imposterCantRemoveValidSigner() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.removeValidSigner(imposter);
    }

    function test_ownerCanRemoveValidSigner() public {
        vm.startPrank(admin);
        prices.addValidSigner(newSigner);

        assertEq(prices.validSigner(newSigner), true);

        prices.removeValidSigner(newSigner);
        assertEq(prices.validSigner(newSigner), false);
    }

    // ***************************************************************
    // * ======================= ADD FEED ========================== *
    // ***************************************************************

    function test_imposterCantAddFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.addFeed('new feed');
    }

    function test_ownerCantAddFeedWithEmptyTitle() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeedTitle()"));
        prices.addFeed('');
    }

    function test_ownerCanAddFeed() public {
        vm.startPrank(admin);

        assertEq(prices.getFeed(1).isValid, false);

        prices.addFeed('new feed');

        assertEq(prices.getFeed(1).isValid, true);
    }

    // ***************************************************************
    // * ===================== REMOVE FEED ========================= *
    // ***************************************************************

    function test_imposterCantRemoveFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.removeFeed(1);
    }

    function test_ownerCanRemoveFeed() public {
        vm.startPrank(admin);
        prices.addFeed('new feed');

        assertEq(prices.getFeed(1).isValid, true);

        prices.removeFeed(1);

        assertEq(prices.getFeed(1).isValid, false);
    }

    // ***************************************************************
    // * ================= UPDATE AGGREGATOR ======================= *
    // ***************************************************************

    function test_imposterCantUpdateAggregator() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updateAggregator(dummyAggregator);
    }

    function test_ownerCantUpdateAggregatorToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidAggregator()"));
        prices.updateAggregator(address(0));
    }

    function test_ownerCanUpdateAggregator() public {
        vm.startPrank(admin);

        MedianAggregator medianAggregator = new MedianAggregator();

        assertEq(address(prices.aggregator()), address(aggregator));

        prices.updateAggregator(address(medianAggregator));

        assertEq(address(prices.aggregator()), address(medianAggregator));
    }

    // ***************************************************************
    // * ================= UPDATE FEE HANDLER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateFeeHandler() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updateFeeHandler(dummyFeeHandler);
    }

    function test_ownerCantUpdateFeeHandlerToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeeHandler()"));
        prices.updateFeeHandler(address(0));
    }

    function test_ownerCanUpdateFeeHandler() public {
        vm.startPrank(admin);

        EvenFeeHandler newFeeHandler = new EvenFeeHandler(admin, protocolFeeReceiver);

        assertTrue(address(feeHandler) != address(newFeeHandler));

        assertEq(address(prices.feeHandler()), address(feeHandler));

        prices.updateFeeHandler(address(newFeeHandler));

        assertEq(address(prices.feeHandler()), address(newFeeHandler));
    }

    // ***************************************************************
    // * ================== TURN OFF PRICES ======================== *
    // ***************************************************************

    function test_imposterCantTurnOffPrices() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.turnOff();
    }

    function test_ownerCanTurnOffPrices() public {
        vm.startPrank(admin);

        assertEq(prices.switchedOn(), true);

        prices.turnOff();

        assertEq(prices.switchedOn(), false);
    }

    // ***************************************************************
    // * =================== TURN ON PRICES ======================== *
    // ***************************************************************

    function test_imposterCantTurnOnPrices() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.turnOn();
    }

    function test_ownerCanTurnOnPrices() public {
        vm.startPrank(admin);
        prices.turnOff();

        assertEq(prices.switchedOn(), false);

        prices.turnOn();

        assertEq(prices.switchedOn(), true);
    }

    // ***************************************************************
    // * ================== UPDATE TOTAL FEE ======================= *
    // ***************************************************************

    function test_imposterCantUpdateTotalFee() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updateTotalFee(1 ether);
    }

    function test_ownerCantUpdateTotalFeeToLessThan1000() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidTotalFee()"));
        prices.updateTotalFee(999);
    }

    function test_ownerCanUpdateTotalFeeToZero() public {
        vm.startPrank(admin);

        assertEq(prices.totalFee(), 0.001 ether);

        prices.updateTotalFee(0);

        assertEq(prices.totalFee(), 0);
    }

    function test_ownerCanUpdateTotalFee() public {
        vm.startPrank(admin);

        assertEq(prices.totalFee(), 0.001 ether);

        prices.updateTotalFee(1 ether);

        assertEq(prices.totalFee(), 1 ether);
    }

}
