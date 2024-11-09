// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
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

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    /// @notice Thrown when the ETH sent is insufficient to participate in the raffle.
    error Raffle_InsufficientETHSent();

    /// @notice Thrown when the transfer of funds fails during the raffle.
    error Raffle_TransferFailed();

    /// @notice Thrown when an attempt is made to join or execute the raffle while it is not open.
    error Raffle_NotOpen();

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
    bytes32 private immutable i_keyhash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    // SubscriptionID of your chainlink VRF subscription
    uint256 private immutable i_subscriptionId;
    // Kaximum amount of gas to allow the callback to use
    uint32 private immutable i_callbackGasLimit = 40000;
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
        i_keyhash = gasLane;
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

    // for system to pick winner
    function pickWinner() external {
        // has enough time passed?
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert("Not enough time passed");
        }

        s_raffleState = RaffleState.CALCULATING;

        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyhash,
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

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];

        // Reset raffle state
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        // send the balance to the winner,l entire balance of this contract
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) revert Raffle_TransferFailed();

        emit WinnerPicked(s_recentWinner);
    }

    /* Getters */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
