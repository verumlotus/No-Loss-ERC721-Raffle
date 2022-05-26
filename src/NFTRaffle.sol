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

    /// @notice the largest ticket number that has been assigned
    uint256 public largestTicketNumber;

    /************************************************
     *  IMMUTABLES & CONSTANTS
    ***********************************************/
    /// @notice the owner of the contract (artist who deposits the NFT up for raffle)
    address public immutable owner;

    /// @notice the underlying token that can be deposited by users. Interest is paid out
    /// to the artist in this token
    address public immutable interestToken;

    /// @notice the end of the raffle period (interest will be generated until this time, 
    /// & user deposits will be frozen before the end of the raffle period)
    uint256 public immutable raffleEndTime;

    /// @notice the end of the deposit period (window of time in which users can deposit interestTokens
    /// to be eligible for the raffle)
    uint256 public immutable depositPeriodEndTime;

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
     * @param _interestToken address of the interestToken
     * @param _depositPeriodLength the length of the deposit period
     * @param _raffleLength the length of the raffle period
     */
    constructor(address _vrfCoordinator, address _interestToken, uint256 _depositPeriodLength, uint256 _raffleLength) VRFConsumerBaseV2(_vrfCoordinator) {
        owner = msg.sender;
        interestToken = _interestToken;
        depositPeriodEndTime = block.timestamp + _depositPeriodLength;
        raffleEndTime = block.timestamp + _depositPeriodLength + _raffleLength;
    }

    /**
     * @notice callback hook called by VRF coordinator
     * @param requestId The Id initially returned by requestRandomness
     * @param randomWords the VRF output expanded to the requested number of words
    */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) override internal {

    }
}
