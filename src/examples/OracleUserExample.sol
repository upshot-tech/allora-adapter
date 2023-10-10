// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import { IOracle, Feed, FeedView, UpshotOracleNumericData } from '../interface/IOracle.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


/**
 * @title OracleUserExample
 * @notice Example contract for using the Upshot Oracle
 */
contract OracleUserExample is Ownable2Step {

    // Sepolia oracle Address
    IOracle public upshotOracle = IOracle(0xA610B62931659779ad06821FFEfEDc48AF087C88);

    constructor () {
        _transferOwnership(msg.sender);
    }

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************

    /**
     * @notice Example for calling a protocol function with a price from the Upshot Oracle
     * 
     * @param protocolFunctionArgument An argument for the protocol function
     * @param upshotOracleData The signed data from the Upshot Oracle
     */
    function callProtocolFunctionWithUpshotOraclePrice(
        uint256 protocolFunctionArgument,
        UpshotOracleNumericData calldata upshotOracleData
    ) external payable {
        uint256 price = upshotOracle.verifyData{value: msg.value}(upshotOracleData);

        _protocolFunctionRequiringPrice(protocolFunctionArgument, price);
    }

    function _protocolFunctionRequiringPrice(uint256 protocolFunctionArgument, uint256 price) internal {
        // use arguments and price 
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Set the Upshot Oracle contract address
     * 
     * @param upshotOraclePrices_ The Upshot Oracle contract address
     */
    function setUpshotOraclePricesContract(IOracle upshotOraclePrices_) external onlyOwner {
        upshotOracle = upshotOraclePrices_;
    }
}
