// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// Call this script to trigger deployment of the raffle contract
contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        return DeployContract();
    }

    function DeployContract() internal returns (Raffle, HelperConfig) {
        // Init helperConfig to get network config
        /*
            HelperConfig will fetch config based on chainId from block object
            We can set the chainId to any value we want, but helperconfig has only 3 configs (Mainnet, Sepolia, Local)
            => Deploy Mock
        */
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // HelperConfig has all the values we need to deploy the raffle contract
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.vrfCoordinatorV2_5,
            config.callbackGasLimit,
            config.entranceFee,
            config.interval
        );

        return (raffle, helperConfig);
    }
}
