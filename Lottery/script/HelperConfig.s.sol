pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

/**
    We need to pass a lot of parameters to the raffle contract.
    Values for these will depend on the blockchain network we deploy to.
    HelperConfig will manage choosing the right values 
    based on target deployment network.
*/
contract HelperConfig is Script {
    function getRaffleParams()
        external
        returns (uint256, uint256, uint256, uint256)
    {
        // Implementation
    }
}
