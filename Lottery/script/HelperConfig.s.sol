// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

/**
 * We need to pass a lot of parameters to the raffle contract.
 *     Values for these will depend on the blockchain network we deploy to.
 *     HelperConfig will manage choosing the right values
 *     based on target deployment network.
 */
abstract contract CodeConstants {
    /* VRF Coordinator Mock Values */
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price (outdateddd)
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    // Default sender address for foundry, used for local testing
    address public FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    /* Chain IDs */
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
        bytes32 gasLane;
        uint256 subscriptionId;
        address vrfCoordinatorV2_5;
        uint32 callbackGasLimit;
        address link;
        address account;
        // Raffle specific
        uint256 entranceFee;
        uint256 interval;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() {
        // Sepolia chainId triggers fetching of Sepolia config
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        // will get config by chainId (which is passed as a block parameter)
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        // Calling code pass a chainId, informing helperConfig of the network
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        // If address not 0, our mapping has a config for this chainId
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig_InvalidChainID();
        }
    }

    /*
        SEPOLIA CONFIG 
        VRFfCoordinator set to the addres specified by chainlink docs
    */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // in seconds, specified in contract
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            // Burner wallet
            account: 0xcFc24B244340e786E1e9c29834Ef95ab524ADB6b
        });
    }

    /*
        MAINNET CONFIG 
        When accessing mainnet
    */
    function getMainnetEthConfig() public view returns (NetworkConfig memory mainnetworkConfig) {
        mainnetworkConfig = NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 60, // in seconds, specified in contract
            vrfCoordinatorV2_5: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            gasLane: 0x3fd2fec10d06ee8f65e7f2e95f5c56511359ece3f33960ad8a866ae24a8ff10b,
            callbackGasLimit: 500000,
            subscriptionId: 1,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            // Burner wallet
            account: 0xcFc24B244340e786E1e9c29834Ef95ab524ADB6b
        });
    }

    /*
        ANVIL CONFIG 
        Config for local development with Anvil
    */
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check for active config, if exist => return it
        if (localNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return localNetworkConfig;
        }
        /**
         * If no valid network config is passed to the contract,
         *         we will create a mock vrCoordinatorV2_5
         *         => enables us to deploy the contract locally! ^^ Yey
         */
        console2.log(unicode"⚠️ You have deployed a mock conract!");
        console2.log("Make sure this was intentional");
        // Broadcast  to simulate real blockchain transactions
        vm.startBroadcast();
        // VRF Coordinator Mock constructor accepts three params
        // These are defined in the CodeConstants contract above
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken linkToken = new LinkToken();
        uint256 mockSubId = vrfCoordinatorV2_5Mock.createSubscription();
        // LinkToken is a mock contract, used to simulate LINK token (since we are on a local network, in reality we would use the real LINK token)
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // doesnt matter (it's just a mock bro)
            subscriptionId: mockSubId,
            vrfCoordinatorV2_5: address(vrfCoordinatorV2_5Mock),
            callbackGasLimit: 500000,
            link: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER,
            entranceFee: 0.01 ether,
            interval: 30 // in seconds, specified in raffle contract
        });
        console2.log("Raffle Config Subscription ID:", localNetworkConfig.subscriptionId);

        vm.deal(localNetworkConfig.account, 100 ether);
        return localNetworkConfig;
    }
}
