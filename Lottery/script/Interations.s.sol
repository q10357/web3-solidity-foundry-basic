// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * Call this contract to create a chainlink subscription
 */
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAddr = helperConfig.getConfig().vrfCoordinatorV2_5;
        (uint256 subID,) = createSubscription(vrfCoordinatorAddr);

        return (subID, vrfCoordinatorAddr);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        // Create Subscription
        console2.log("Creating subscription on chain ID: ", block.chainid);
        vm.startBroadcast();
        uint256 subID = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();

        console2.log("Your subscription ID: ", subID);
        console2.log("Update the subscription ID in HelperConfig.s.sol:");

        return (subID, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}
