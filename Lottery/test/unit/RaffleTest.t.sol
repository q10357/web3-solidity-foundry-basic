// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

// CodeConstants are defined in HelperConfig.s.sol
contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 raffleInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;

    /* Events - Had to Copy to "mock" an Emit  */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        // Prepare test environment
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        /**
         * Our Raffle contract needs the specified parameters to be initiated
         * We can get these parameters from the HelperConfig contract
         */
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        raffleEntranceFee = config.entranceFee;
        raffleInterval = config.interval;

        // Deal some ETH to the player
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                            RAFFLE ENTRY TESTS
    //////////////////////////////////////////////////////////////*/
    /**
     * We need to send the correct amount of ETH to enter the raffle
     * If we don't send enough, the transaction will revert
     * NB: vm.prank() is a helper function that sends a transaction with a specified amount of ETH
     * it will only be applied to the next transaction (in this case, enterRaffle())
     */
    function testRaffleRevertsWHenYouDontPayEnought() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle_InsufficientETHSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersUponEntering() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: raffleEntranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert (NB: the expectEmit function will assert for us)
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    /*
     * Test that the raffle reverts when attempting to enter while in CALCULATING state.
        state, wm.warp is able to change the block.timestamp (simulates time passing)
        It enables the performUpkeep() function to be called. PerormUpkeep() changes the state to CALCULATING
     **/
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffleInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act / Assert
        vm.expectRevert(Raffle.Raffle_NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    /**
     * CheckUpkeep should return false if raffle has no balance
     */
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + raffleInterval + 1); // interval is good
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert (balance is 0, and no players)
        assert(!upkeepNeeded);
    }

    /**
     * CheckUpkeep should return false if raffle is not open
     */
    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}(); // balance and players are good
        vm.warp(block.timestamp + raffleInterval + 1); // interval is good (time passed)
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // raffle is now in CALCULATING state
        // Assert
        assert(!upkeepNeeded);
    }
}
