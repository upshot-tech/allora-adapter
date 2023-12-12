// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IUpshotAdapter, Topic, TopicView, UpshotAdapterNumericData } from '../interface/IUpshotAdapter.sol';
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


/**
 * @title UpshotAdapterBringPredictionOnChainExample
 * @notice Example contract for using the Upshot adapter by bringing predictions on-chain
 */
contract UpshotAdapterBringPredictionOnChainExample is Ownable2Step {

    // Sepolia adapter Address
    IUpshotAdapter public upshotAdapter = IUpshotAdapter(0xdD3C703221c7F00Fe0E2d8cdb5403ca7760CDd4c);

    constructor () {
        _transferOwnership(msg.sender);
    }

    // ***************************************************************
    // * ================== USER INTERFACE ========================= *
    // ***************************************************************

    /**
     * @notice Example for calling a protocol function with a price from the Upshot Adapter
     * 
     * @param protocolFunctionArgument An argument for the protocol function
     * @param upshotAdapterData The signed data from the Upshot Adapter
     */
    function callProtocolFunctionWithUpshotAdapterPrice(
        uint256 protocolFunctionArgument,
        UpshotAdapterNumericData calldata upshotAdapterData
    ) external payable {
        uint256 price = upshotAdapter.verifyData{value: msg.value}(upshotAdapterData);

        _protocolFunctionRequiringPrice(protocolFunctionArgument, price);
    }

    function _protocolFunctionRequiringPrice(uint256 protocolFunctionArgument, uint256 price) internal {
        // use arguments and price 
    }

    // ***************************************************************
    // * ========================= ADMIN =========================== *
    // ***************************************************************

    /**
     * @notice Set the UpshotAdapter contract address
     * 
     * @param upshotAdapter_ The UpshotAdapter contract address
     */
    function setUpshotAdapterContract(IUpshotAdapter upshotAdapter_) external onlyOwner {
        upshotAdapter = upshotAdapter_;
    }
}
