// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/VRFConsumerBaseV2.sol";
import "@oz/token/ERC721/IERC721Receiver.sol";
import "@oz/token/ERC721/IERC721.sol";
import "@oz/token/ERC20/IERC20.sol";
import "@oz/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IYearnVault.sol";

/**
 * @title No-loss NFT Raffle
 * @notice No-loss NFT raffle that deposits user funds into a yield-bearing strategy and forwards all interest to NFT creator.
 * @author verumlotus
 */
contract NFTRaffle is VRFConsumerBaseV2, IERC721Receiver {
    using SafeERC20 for IERC20;
    /************************************************
     *  STORAGE
    ***********************************************/
    /// @notice the ticket number that wins the raffle. This is the chainlink 
    /// VRF number modulo the number of tickets
    uint256 public winningTicket;

    /// @notice flag to indicate whether a winningTicket has been selected
    bool public winnerSet = false;

    /// @notice address of the ERC721 asset
    address public nftAddress;

    /// @notice id of the ERC721 asset
    uint256 public nftId;

    /// @notice the largest ticket number that has been assigned
    uint256 public largestTicketNumber;

    /// @notice mapping from user addr => array of Range structs
    mapping(address => Range[]) public userTickets;

    /// @notice balance of interestToken of this contracrt 
    /// before investing in yield strategy
    uint256 public interestTokenBalanceBefore;

    /// @notice the amount of interest generated (calcualted after withdrawing from Yearn)
    uint256 public interestGenerated;

    /// @notice mapping to flag whether user has withdrawn funds
    mapping(address => bool) public withdrawnFunds;

    /// @notice flag if a random word was requested
    bool public randomWordRequested;

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

    /// @notice address of the Yearn Vault for the interestToken
    address public immutable yearnVault;

    /// @notice address of the VRF coordinator for this chain 
    address public immutable vrfCoordinator;

    /// @notice chainlink subscription id for chainlink VRF v2.0
    uint64 public immutable chainlinkSubscriptionId;

    /// @notice key hash to specify the gas lane to utilize during the callback
    bytes32 public constant KEY_HASH = 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92; 

    /// @notice maximum amount of gas we are willing to spend on the chainlink callback
    uint32 public constant CALL_BACK_GAS_LIMIT = 1e5;

    /// @notice number of block confirmations before the chainlink VRF random word(s) are returned
    uint16 public constant REQUEST_CONFIRMATIONS = 3;

    /************************************************
     *  EVENTS, ERRORS, MODIFIERS, STRUCTS
    ***********************************************/
    /// @notice Range struct to store range of tickets owned by a user
    struct Range {
        /// lowest ticket number
        uint256 lowerBound;
        /// highest ticket number
        uint256 upperBound;
    }

    /// @notice emitted when the raffle is entered
    event RaffleEntered(address indexed depositor, uint256 amount);

    /// @notice emitted when NFT is deposited by artist
    event NFTDeposited(address nftAddress, uint256 tokenId);

    /// @notice emitted when raffle deposits are invested
    event RaffleDepositsInvested(address indexed yearnVault, uint256 amount);

    /// @notice emitted when a user withdraws funds
    event FundsWithdrawn(address indexed depositor, uint256 amount);

    /// @notice emitted when the NFT is claimed by the winner
    event NFTClaimed(address winner);

    /// @notice restricts function call to owner of the contract
    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /// @notice restricts function call to only when deposit period is active
    modifier depositPeriodActive {
        require(block.timestamp <= depositPeriodEndTime, "Deposit period has ended");
        _;
    }

    /// @notice ensures that the NFT has been escrowed in this contract
    modifier nftDeposited {
        require(nftAddress != address(0));
        _;
    }

    /**
     * @notice constructs a raffle contract 
     * @param _vrfCoordinator address of the chainlink VRF coordinator for the desired chain
     * @param _interestToken address of the interestToken
     * @param _depositPeriodLength the length of the deposit period
     * @param _interestGenerationPeriod the length of the interest generation period
     * @param _yearnVault address of the yearn vault
     * @param _chainlinkSubscriptionId id of the chainlink VRF subscription 
     */
    constructor(address _vrfCoordinator, address _interestToken, uint256 _depositPeriodLength, uint256 _interestGenerationPeriod, address _yearnVault, uint64 _chainlinkSubscriptionId) VRFConsumerBaseV2(_vrfCoordinator) {
        vrfCoordinator = _vrfCoordinator;
        owner = msg.sender;
        interestToken = _interestToken;
        depositPeriodEndTime = block.timestamp + _depositPeriodLength;
        raffleEndTime = block.timestamp + _depositPeriodLength + _interestGenerationPeriod;
        yearnVault = _yearnVault;
        chainlinkSubscriptionId = _chainlinkSubscriptionId;
    }

    /**
     * @notice transfers the NFT for raffle from the owner to this contract
     * @dev note that the owner must call approve() or setApprovalForAll() before calling this function 
     * @param _nftAddress address of the NFT contract
     * @param _tokenId tokenId of the specific NFT up for raffle
     */
    function depositNFT(address _nftAddress, uint256 _tokenId) external onlyOwner {
        // Attempt to transfer NFT from owner to this contract
        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
        nftAddress = _nftAddress;
        nftId = _tokenId;
        emit NFTDeposited(_nftAddress, _tokenId);
    }

    /**
     * @notice allows a user to enter the raffle
     * @param amount the amount to enter into the raffle
     */
    function enterRaffle(uint256 amount) external nftDeposited depositPeriodActive {
        // Transfer amount interestTokens to this contract
        IERC20(interestToken).safeTransferFrom(msg.sender, address(this), amount);
        Range memory range = Range(largestTicketNumber, largestTicketNumber + amount - 1);
        // Add the tickets to the user
        userTickets[msg.sender].push(range);
        // Update largest ticket number
        largestTicketNumber = largestTicketNumber + amount;
        emit RaffleEntered(msg.sender, amount);
    }

    /**
     * @notice allows for the owner to deposit the raffle deposits in a yield bearing strategy
     */
    function investRaffleDeposits() external onlyOwner {
        // Ensure that the deposit period has finished, but the interest generation period is active
        require(depositPeriodEndTime < block.timestamp 
            && block.timestamp < raffleEndTime, 
            "Invalid timeframe to invest raffle deposits");
        interestTokenBalanceBefore = IERC20(interestToken).balanceOf(address(this));
        // Approve the yearn vault to pull tokens 
        IERC20(interestToken).approve(yearnVault, interestTokenBalanceBefore);
        IYearnVault(yearnVault).deposit(interestTokenBalanceBefore);
        emit RaffleDepositsInvested(yearnVault, interestTokenBalanceBefore);
    }

    /**
     * @notice burns all our yearn shares and returns us the deposit + interest
     * @dev notice that this assumes interest is positive - this is not always the case!
     */
    function withdrawRaffleDepositsFromYearn() external {
        // Require that the Raffle has ended
        require(block.timestamp > raffleEndTime, "Raffle has not ended");
        // Also, require that we have not already called this function 
        require(interestGenerated == 0, "shares from Yearn already burned");
        // Will burn all our shares and return original deposit + interest
        IYearnVault(yearnVault).withdraw();
        uint256 interestTokenBalance = IERC20(interestToken).balanceOf(address(this));
        // This assumes that a positive interest was generated! (not always the case)
        interestGenerated = interestTokenBalance - interestTokenBalanceBefore;
        // Transfer interestGenerated to the artist (the owner)
        IERC20(interestToken).transfer(owner, interestGenerated);
    }

    /**
     * @notice allow users to withdraw their funds after the raffle period has ended
     */
    function withdrawRaffleDeposit() external {
        // Require that the Raffle has ended
        require(block.timestamp > raffleEndTime, "Raffle has not ended");
        // Ensure user hasn't already withdrawn funds
        require(withdrawnFunds[msg.sender] == false, "User has already withdrawn funds");
        uint256 amountToReturn = 0;
        Range[] memory depositRanges = userTickets[msg.sender];
        // Loops are ugly ik! But a user should have realistically only deposited maximum a few times over
        // the course of the raffle, so it won't gobble too much gas. 
        for (uint i = 0; i < depositRanges.length; i++) {
            Range memory range = depositRanges[i];
            amountToReturn += range.upperBound - range.lowerBound + 1;
        }
        // Mark user as having withdrawn funds
        withdrawnFunds[msg.sender] = true;
        // Transfer funds to user
        IERC20(interestToken).safeTransfer(msg.sender, amountToReturn);
        emit FundsWithdrawn(msg.sender, amountToReturn);
    }

    function requestRandomWords() external {
        // Anyone can call this function if the raffle period has ended
        require(block.timestamp > raffleEndTime, "raffle has not ended");

        // You can only re-call this function, 7 days after the raffle period 
        // has ended: this is to account for a reverted Tx with the Chainlink VRF
        // callback
        require(block.timestamp > raffleEndTime + 7 days ||
            randomWordRequested == false);
        randomWordRequested = true;
        VRFCoordinatorV2Interface(vrfCoordinator).requestRandomWords(
            KEY_HASH, 
            chainlinkSubscriptionId, 
            REQUEST_CONFIRMATIONS, 
            CALL_BACK_GAS_LIMIT, 
            1
        );
    }

    /**
     * @notice callback hook called by VRF coordinator
     * @param randomWords the VRF output expanded to the requested number of words
    */
    function fulfillRandomWords(uint256, uint256[] memory randomWords) override internal {
        // Will be a number between 0 < X < largestTicketNumber 
        winningTicket = randomWords[0] % largestTicketNumber;
        winnerSet = true;
    }

    /**
     * @notice allows a user to claim the NFT if they are a winner
     */
    function claimWinner() external {
        require(winnerSet = true, "A winner has not been declared!");
        Range[] memory depositRanges = userTickets[msg.sender];
        // Loops are ugly ik! But a user should have realistically only deposited maximum a few times over
        // the course of the raffle, so it won't gobble too much gas. 
        bool isWinner = false;
        for (uint i = 0; i < depositRanges.length; i++) {
            Range memory range = depositRanges[i];
            if (winningTicket >= range.lowerBound && winningTicket <= range.upperBound) {
                isWinner = true;
                break;
            }
        }
        require(isWinner, "Caller is not a winner!");
        IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, nftId);
        emit NFTClaimed(msg.sender);
    }

    /**
     * @inheritdoc IERC721Receiver
     */
    function onERC721Received(address, address, uint256, bytes memory) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
