// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// Call this script to trigger deployment of the raffle contract
contract DeployRaffle is Script {
    function run() external {
        DeployContract();
    }

    function DeployContract() internal returns (Raffle, HelperConfig) {
        // Init helperConfig to get network config
        /*
            HelperConfig will fetch config based on chainId from block object
            We can set the chainId to any value we want, but helperconfig has only 3 configs (Mainnet, Sepolia, Local)
            => Deploy Mock
        */
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.networkConfigs memory config = helperConfig.getConfig();
    }
}
