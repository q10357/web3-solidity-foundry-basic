// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

contract Raffle {
    uint256 private immutable i_entranceFee;
    // @dev Duration of the raffle in seconds
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

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
    }

    /* Getters */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
