// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// This script deploys the raffle contract
contract DeployRaffle is Script {
    function run() external {
        DeployContract();
    }

    function DeployContract() internal returns (Raffle, HelperConfig) {
        // Implementation
    }
}
