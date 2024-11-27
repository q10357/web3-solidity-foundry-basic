// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interations.s.sol";

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

        // If the subscriptionID is 0, we won't be able to call chainlink VRF (need to have valid subscription and added as consumer)
        // ? => we need to set create a subscription
        if (config.subscriptionId == 0) {
            // create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5);
            // Next => Fund it!
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinatorV2_5, config.subscriptionId, config.link);
            // We will add a consumer, but AFTER Raffle contract is deployed
            // This is because we need the (most recently deployed) Raffle contract address to add it as a consumer
        }

        // HelperConfig has all the values we need to deploy the raffle contract
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.vrfCoordinatorV2_5,
            config.callbackGasLimit,
            config.entranceFee,
            config.interval
        );

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(vrfCoordinator, subID, config.link, address(raffle));

        return (raffle, helperConfig);
    }
}
