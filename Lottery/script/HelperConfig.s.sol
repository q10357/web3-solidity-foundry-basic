// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

/**
 * We need to pass a lot of parameters to the raffle contract.
 *     Values for these will depend on the blockchain network we deploy to.
 *     HelperConfig will manage choosing the right values
 *     based on target deployment network.
 */
abstract contract CodeConstants {
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    /*//////////////////////////////////
                    ERRORS
    //////////////////////////////////*/
    error HelperConfig_InvalidChainID();

    /*//////////////////////////////////
                    TYPES
    //////////////////////////////////*/
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinatorV2_5;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
    }

    /*//////////////////////////////////
                STATE VARIABLES 
    //////////////////////////////////*/
    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    /*//////////////////////////////////
                FUNCTIONS 
    //////////////////////////////////*/
    constructor() {
        // Sepolia chainId triggers fetching of Sepolia config
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
    }

    function getConfig(uint256 chainId) public returns (NetworkConfig memory) {
        // will get config by chain
    }

    function setConfig(
        uint256 chainId,
        NetworkConfig memory networkConfig
    ) public {
        // Calling code pass a chainId, informing helperConfig of the network
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(
        uint256 chainId
    ) public view returns (NetworkConfig memory) {
        // If address not 0, our mapping has a config for this chainId
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig_InvalidChainID();
        }
    }

    /*
        SEPOLIA CONFIG 
        VRFfCoordinator set to the addres specified by chainlink docs
    */
    function getSepoliaEthConfig()
        public
        pure
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // in seconds, specified in contract
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0
        });
    }

    /*
        MAINNET CONFIG 
        When accessing mainnet
    */
    function getMainnetEthConfig()
        public
        pure
        returns (NetworkConfig memory mainnetworkConfig)
    {
        mainnetworkConfig = NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 60, // in seconds, specified in contract
            vrfCoordinatorV2_5: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            gasLane: 0x3fd2fec10d06ee8f65e7f2e95f5c56511359ece3f33960ad8a866ae24a8ff10b,
            callbackGasLimit: 500000,
            subscriptionId: 1
        });
    }

    /*
        ANVIL CONFIG 
        Config for local development with Anvil
    */
    function getOrCreateAnvilConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        // if we have a config, return it
        if (localNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return localNetworkConfig;
        }

        // else, create a new one
    }
}
