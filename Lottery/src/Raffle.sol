// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import "forge-std/console.sol";

// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract

// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Errors */
    /// @notice Thrown when the ETH sent is insufficient to participate in the raffle.
    error Raffle_InsufficientETHSent();

    /// @notice Thrown when the transfer of funds fails during the raffle.
    error Raffle_TransferFailed();

    /// @notice Thrown when an attempt is made to join or execute the raffle while it is not open.
    error Raffle_NotOpen();

    //// @notice Thrown when performUpkeep is called but the upkeep is not needed.
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    /* Type Declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1

    }

    /* State Variables */
    // Constants
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 2;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/vrf/v2-5/supported-networks#configurations
    bytes32 private immutable i_gasLane;
    // SubscriptionID of your chainlink VRF subscription
    uint256 private immutable i_subscriptionId;
    // Kaximum amount of gas to allow the callback to use
    uint32 private immutable i_callbackGasLimit;
    // Entrance fee to join the raffle
    uint256 private immutable i_entranceFee;
    // Required time to elapse between consecutive winners (in seconds)
    uint256 private immutable i_interval;

    address payable[] private s_players;
    address payable private s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    /* Events */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // for users to enter
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee;, "Not enough ETH!");
        if (msg.value < i_entranceFee) revert Raffle_InsufficientETHSent();
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);

        if (s_raffleState != RaffleState.OPEN) revert Raffle_NotOpen();
    }

    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Automatically called
    function performUpkeep(bytes calldata /* performData */ ) external override {
        // Chainlink node may call function, as well as anyone else
        // For security reasons, we ensure that the upkeep is needed
        (bool upkeepNeeded,) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * If it returns True, `performUpkeep` is called
     * => Winner is picked and balance is sent to cette winner
     * NB: Parameter checkData is not used in this contract
     *
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;

        // All is true => upkeep is needed => call performUpKeep
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];

        // Reset raffle state
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        // send the balance to the winner,l entire balance of this contract
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) revert Raffle_TransferFailed();

        emit WinnerPicked(s_recentWinner);
    }

    /* Getters */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
