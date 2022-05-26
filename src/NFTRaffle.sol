// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/VRFConsumerBaseV2.sol";

/**
 * @title No-loss NFT Raffle
 * @notice No-loss NFT raffle that deposits user funds into a yield-bearing strategy and forwards all interest to NFT creator.
 * @author verum
 */
contract NFTRaffle is VRFConsumerBaseV2 {
    /************************************************
     *  STORAGE
    ***********************************************/
    /// @notice the ticket number that wins the raffle. This is the chainlink 
    /// VRF number modulo the number of tickets
    uint256 public winningTicket;

    /************************************************
     *  IMMUTABLES & CONSTANTS
    ***********************************************/
    /// @notice key hash to specify the gas lane to utilize during the callback
    bytes32 public constant KEY_HASH = 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92; 

    /// @notice maximum amount of gas we are willing to spend on the chainlink callback
    uint32 public constant CALL_BACK_GAS_LIMIT = 1e5;

    /// @notice number of block confirmations before the chainlink VRF random word(s) are returned
    uint16 public constant REQUEST_CONFIRMATIONS = 3;

    /************************************************
     *  EVENTS, ERRORS, MODIFIERS
    ***********************************************/

    /**
     * @notice constructs a raffle contract 
     * @param _vrfCoordinator address of the chainlink VRF coordinator for the desired chain
     */
    constructor(address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {}


}
