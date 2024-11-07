// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

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

error Raffle_NotEnoughEthSent();

contract Raffle is VRFConsumerBaseV2Plus {
    uint256 private immutable i_entranceFee;
    // @dev Duration of the raffle in seconds
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/vrf/v2-5/supported-networks#configurations
    bytes32 public s_keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    uint256 public s_subscriptionId;
    uint32 public callbackGasLimit = 40000;

    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    // for users to enter
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH!");
        if (msg.value < i_entranceFee) revert Raffle_NotEnoughEthSent();
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // for system to pick winner
    function pickWinner() external {
        // has enough time passed?
        if (block.timestamp - s_lastTimeStamp < i_interval) revert();

        // Will revert if subscription is not set and funded.
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    /* Getters */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
