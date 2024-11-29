// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

/**
 * Call this contract to create a chainlink subscription
 */
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAddr = helperConfig.getConfig().vrfCoordinatorV2_5;
        // Fetching the subscription ID from the current network configuration.
        // This ID is required to link the VRF subscription for randomness requests.
        (uint256 subID,) = createSubscription(vrfCoordinatorAddr, helperConfig.getConfig().account);

        return (subID, vrfCoordinatorAddr);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        // Create Subscription
        console2.log("Creating subscription on chain ID: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subID = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console2.log("Your subscription ID: ", subID);
        console2.log("Update the subscription ID in HelperConfig.s.sol:");

        return (subID, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

/**
 * Call this contract to fund  a chainlink subscription
 */
contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 300 ether; // LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        fundSubscription(config.vrfCoordinatorV2_5, config.subscriptionId, config.link, config.account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subID, address link, address account) public {
        // Fund Subscription
        console2.log("Funding subscription: ", subID);
        console2.log("Using vrfCoordinator: ", subID);
        console2.log("On chainID: ", block.chainid);

        // NB: We can refer to value LOCAL_CHAIN_ID since we inherit CodeConstants
        if (block.chainid == LOCAL_CHAIN_ID) {
            // Mock LINK token (chainID is local)
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subID, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            // Actual LINK token (chainID is not local)
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subID));
            vm.stopBroadcast();
        }
        console2.log("Subscription funded!");
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    /**
     * So, we have a subscription and it's funded. Now, we need to add a consumer contract
     * This is all because performUpkeep() returns InvalidConsumer()
     * It may seem like a lot, and it is. But it's a one-time setup.
     * Interactions now contains three contracts, being:
     *     1. CreateSubscription: Creates a VRF subscription
     *     2. FundSubscription: Funds link to that subscription
     *     3. AddConsumer: Adds this contract as a consumer of the subscription
     */
    function addConsumerUsingConfig(address consumerAddr) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        addConsumer(config.vrfCoordinatorV2_5, config.subscriptionId, config.link, consumerAddr, config.account);
    }

    function addConsumer(address vrfCoordinator, uint256 subID, address link, address consumer, address account)
        public
    {
        console2.log("Adding consumer: ", consumer);
        console2.log("To subscription: ", subID);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);
        console2.log("On chainID: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subID, consumer);
        vm.stopBroadcast();
        console2.log("Consumer added!");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
