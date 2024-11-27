// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
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

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAddr = helperConfig.getConfig().vrfCoordinatorV2_5;
        uint256 subscriptionID = helperConfig.getConfig().subscriptionId;
        // Fetching the LINK token contract address (mock on local, actual on live networks).
        // This address is needed to interact with the LINK token, such as funding the subscription.
        address linkToken = helperConfig.getConfig().link;

        fundSubscription(vrfCoordinatorAddr, subscriptionID, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subID, address link) public {
        // Fund Subscription
        console2.log("Funding subscription: ", subID);
        console2.log("Using vrfCoordinator: ", subID);
        console2.log("On chainID: ", block.chainid);

        // NB: We can refer to value LOCAL_CHAIN_ID since we inherit CodeConstants
        if(block.chainid == LOCAL_CHAIN_ID) {
            // We can mint LINK tokens because of it being a mock on local/ test network)
            // Usually, we would transfer LINK tokens from the deployer's wallet.
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subID, FUND_AMOUNT);
            LinkToken(link).mint(address(this), FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            // Actual LINK token
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subID));
            vm.stopBroadcast();
        }
        console2.log("Subscription funded!");
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}
