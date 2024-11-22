# Proveably Random Raffle Contract

## Overview

A smart contract that facilitates a fair and random raffle system on the Ethereum blockchain using Chainlink VRF for randomness and Chainlink Automation for regular draws.

## Features

-   Users can join the raffle by paying an entry fee.
-   Automatic winner selection based on a set interval.
-   Chainlink VRF ensures verifiable randomness.
-   Chainlink Automation triggers the draw at regular intervals.

## Contract Details

### `Raffle.sol`

Manages raffle entries, winner selection, and prize distribution.

### Key Components

-   **Errors**: Custom errors for insufficient ETH, transfer failures, and closed raffles.
-   **State Variables**: Entrance fee, participants, recent winner, etc.
-   **Events**: `EnteredRaffle`, `WinnerPicked`.

## Usage

1. **Enter the Raffle**: Call `enterRaffle()` with the entry fee.
2. **Pick Winner**: Triggered by Chainlink Automation or manually.

## Security

-   Uses Chainlink VRF for fairness.
-   State updates before external calls to prevent reentrancy.
