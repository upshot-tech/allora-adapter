// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Prices, PricesConstructorArgs} from "../src/Prices.sol";
import {PriceData, Feed} from "../src/interface/IPrices.sol";
import {EvenFeeHandler, EvenFeeHandlerConstructorArgs} from "../src/feeHandler/EvenFeeHandler.sol";
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
    IAggregator dummyAggregator = IAggregator(address(202));
    IFeeHandler dummyFeeHandler = IFeeHandler(address(202));

    uint256 signer0pk = 0x1000;
    address signer0;
    address[] oneValidSigner;

    function setUp() public {
        vm.warp(1 hours);

        aggregator = new AverageAggregator();
        feeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin,
            protocolFeeReceiver: protocolFeeReceiver
        }));
        prices = new Prices(PricesConstructorArgs({
            admin: admin
        }));

        oneValidSigner = new address[](1);
        oneValidSigner[0] = signer0;

        vm.startPrank(admin);
        prices.addFeed('Initial feed', aggregator, feeHandler, oneValidSigner);
        vm.stopPrank();
    }

    // ***************************************************************
    // * =================== UPDATE MIN PRICES ===================== *
    // ***************************************************************

    function test_imposterCantUpdateMinPrices() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updateMinPrices(1, 3);
    }

    function test_ownerCantUpdateMinPricesToZero() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2PricesInvalidMinPrices()"));
        prices.updateMinPrices(1, 0);
    }

    function test_ownerCanUpdateMinPrices() public {
        vm.startPrank(admin);

        assertEq(prices.getFeed(1).minPrices, 1);

        prices.updateMinPrices(1, 2);
        assertEq(prices.getFeed(1).minPrices, 2);
    }

    // ***************************************************************
    // * ============= UPDATE PRICE VALIDITY SECONDS =============== *
    // ***************************************************************

    function test_imposterCantUpdatePriceValiditySeconds() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updatePriceValiditySeconds(1, 10 minutes);
    }

    function test_ownerCantUpdatePriceValiditySecondsToZero() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidPriceValiditySeconds()"));
        prices.updatePriceValiditySeconds(1, 0);
    }

    function test_ownerCanUpdatePriceValiditySeconds() public {
        vm.startPrank(admin);

        assertEq(prices.getFeed(1).priceValiditySeconds, 5 minutes);

        prices.updatePriceValiditySeconds(1, 10 minutes);
        assertEq(prices.getFeed(1).priceValiditySeconds, 10 minutes);
    }

    // ***************************************************************
    // * ==================== ADD VALID SIGNER ===================== *
    // ***************************************************************

    function test_imposterCantAddValidSigner() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.addValidSigner(1, imposter);
    }

    function test_ownerCanAddValidSigner() public {
        vm.startPrank(admin);

        assertEq(_contains(newSigner, prices.getFeed(1).validPriceProviders), false);

        prices.addValidSigner(1, newSigner);
        assertEq(_contains(newSigner, prices.getFeed(1).validPriceProviders), true);
    }

    // ***************************************************************
    // * ================== REMOVE VALID SIGNER ==================== *
    // ***************************************************************

    function test_imposterCantRemoveValidSigner() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.removeValidSigner(1, imposter);
    }

    function test_ownerCanRemoveValidSigner() public {
        vm.startPrank(admin);
        prices.addValidSigner(1, newSigner);

        assertEq(_contains(newSigner, prices.getFeed(1).validPriceProviders), true);

        prices.removeValidSigner(1, newSigner);
        assertEq(_contains(newSigner, prices.getFeed(1).validPriceProviders), false);
    }

    // ***************************************************************
    // * ======================= ADD FEED ========================== *
    // ***************************************************************

    function test_imposterCantAddFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.addFeed('second feed', aggregator, feeHandler, oneValidSigner);
    }

    function test_ownerCantAddFeedWithEmptyTitle() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeedTitle()"));
        prices.addFeed('', aggregator, feeHandler, oneValidSigner);
    }

    function test_ownerCanAddFeed() public {
        vm.startPrank(admin);

        assertEq(prices.getFeed(2).isValid, false);

        prices.addFeed('second feed', aggregator, feeHandler, oneValidSigner);

        assertEq(prices.getFeed(2).isValid, true);
    }

    function test_addingFeedGivesProperId() public {
        vm.startPrank(admin);
        uint256 secondFeedId = prices.addFeed('second feed', aggregator, feeHandler, oneValidSigner);
        uint256 thirdFeedId = prices.addFeed('third feed', aggregator, feeHandler, oneValidSigner);

        assertEq(secondFeedId, 2);
        assertEq(thirdFeedId, 3);
        assertEq(prices.getFeed(2).isValid, true);
        assertEq(prices.getFeed(3).isValid, true);
    }

    // ***************************************************************
    // * ===================== REMOVE FEED ========================= *
    // ***************************************************************

    function test_imposterCantTurnOffFeed() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.turnOffFeed(1);
    }

    function test_ownerCanTurnOffFeed() public {
        vm.startPrank(admin);

        assertEq(prices.getFeed(1).isValid, true);

        prices.turnOffFeed(1);

        assertEq(prices.getFeed(1).isValid, false);
    }

    // ***************************************************************
    // * ================= UPDATE AGGREGATOR ======================= *
    // ***************************************************************

    function test_imposterCantUpdateAggregator() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updateAggregator(1, dummyAggregator);
    }

    function test_ownerCantUpdateAggregatorToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidAggregator()"));
        prices.updateAggregator(1, IAggregator(address(0)));
    }

    function test_ownerCanUpdateAggregator() public {
        vm.startPrank(admin);

        MedianAggregator medianAggregator = new MedianAggregator();

        assertEq(address(prices.getFeed(1).aggregator), address(aggregator));

        prices.updateAggregator(1, medianAggregator);

        assertEq(address(prices.getFeed(1).aggregator), address(medianAggregator));
    }

    // ***************************************************************
    // * ================= UPDATE FEE HANDLER ====================== *
    // ***************************************************************

    function test_imposterCantUpdateFeeHandler() public {
        vm.startPrank(imposter);

        vm.expectRevert('Ownable: caller is not the owner');
        prices.updateFeeHandler(1, dummyFeeHandler);
    }

    function test_ownerCantUpdateFeeHandlerToZeroAddress() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidFeeHandler()"));
        prices.updateFeeHandler(1, IFeeHandler(address(0)));
    }

    function test_ownerCanUpdateFeeHandler() public {
        vm.startPrank(admin);

        EvenFeeHandler newFeeHandler = new EvenFeeHandler(EvenFeeHandlerConstructorArgs({
            admin: admin,
            protocolFeeReceiver: protocolFeeReceiver
        }));

        assertTrue(address(feeHandler) != address(newFeeHandler));

        assertEq(address(prices.getFeed(1).feeHandler), address(feeHandler));

        prices.updateFeeHandler(1, newFeeHandler);

        assertEq(address(prices.getFeed(1).feeHandler), address(newFeeHandler));
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
        prices.updateTotalFee(1, 1 ether);
    }

    function test_ownerCantUpdateTotalFeeToLessThan1000() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSignature("UpshotOracleV2InvalidTotalFee()"));
        prices.updateTotalFee(1, 999);
    }

    function test_ownerCanUpdateTotalFeeToZero() public {
        vm.startPrank(admin);

        assertEq(prices.getFeed(1).totalFee, 0.001 ether);

        prices.updateTotalFee(1, 0);

        assertEq(prices.getFeed(1).totalFee, 0);
    }

    function test_ownerCanUpdateTotalFee() public {
        vm.startPrank(admin);

        assertEq(prices.getFeed(1).totalFee, 0.001 ether);

        prices.updateTotalFee(1, 1 ether);

        assertEq(prices.getFeed(1).totalFee, 1 ether);
    }

    function _contains(address needle, address[] memory haystack ) internal pure returns (bool) {
        for (uint i = 0; i < haystack.length; i++) {
            if (haystack[i] == needle) {
                return true;
            }
        }
        return false;
    }
}
